//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation
import WireMessageStrategy
import WireDataModel


extension ZMConversation {
    @objc (appendCallingMessageWithContent:)
    public func appendCallingMessage(content: String) -> ZMClientMessage? {
        let genericMessage = ZMGenericMessage(callingContent: content, nonce: NSUUID().transportString())
        return self.append(genericMessage, expires: false, hidden: true)
    }
}

@objc
public final class CallingRequestStrategy : NSObject, RequestStrategy {
    
    fileprivate let zmLog = ZMSLog(tag: "calling")
    
    fileprivate var callCenter              : WireCallCenterV3?
    fileprivate let managedObjectContext    : NSManagedObjectContext
    fileprivate let genericMessageStrategy  : GenericMessageRequestStrategy
    fileprivate let flowManager             : FlowManagerType
    fileprivate var callConfigRequestSync   : ZMSingleRequestSync! = nil
    fileprivate var callConfigCompletion    : CallConfigRequestCompletion? = nil
    
    public init(managedObjectContext: NSManagedObjectContext, clientRegistrationDelegate: ClientRegistrationDelegate, flowManager: FlowManagerType) {
        self.managedObjectContext = managedObjectContext
        self.genericMessageStrategy = GenericMessageRequestStrategy(context: managedObjectContext, clientRegistrationDelegate: clientRegistrationDelegate)
        self.flowManager = flowManager
        super.init()
        
        let selfUser = ZMUser.selfUser(in: managedObjectContext)
        self.callConfigRequestSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: self.managedObjectContext)
        
        if let userId = selfUser.remoteIdentifier, let clientId = selfUser.selfClient()?.remoteIdentifier {
            callCenter = WireCallCenterV3Factory.callCenter(withUserId: userId, clientId: clientId, uiMOC: managedObjectContext.zm_userInterface, flowManager: flowManager, analytics: managedObjectContext.analytics)
            callCenter?.transport = self
        }
    }
    
    public func nextRequest() -> ZMTransportRequest? {
        zmLog.debug("CallingRequestStrategy nextRequest()")
        if let request = self.callConfigRequestSync.nextRequest() {
            zmLog.debug("callConfigRequestSync nextRequest()")
            return request
        }
        
        return genericMessageStrategy.nextRequest()
    }
    
    public func dropPendingCallMessages(for conversation: ZMConversation) {
        genericMessageStrategy.expireEntities(withDependency: conversation)
    }
    
}


extension CallingRequestStrategy : ZMSingleRequestTranscoder {
    public func request(for sync: ZMSingleRequestSync) -> ZMTransportRequest? {
        zmLog.debug("Scheduling request to '/calls/config'")
        return ZMTransportRequest(path: "/calls/config", method: .methodGET, binaryData: nil, type: "application/json", contentDisposition: nil, shouldCompress: true)
    }
    
    public func didReceive(_ response: ZMTransportResponse, forSingleRequest sync: ZMSingleRequestSync) {
        
        zmLog.debug("Received response for \(self): \(response)")
        var payloadAsString : String? = nil
        if let payload = response.payload, let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
            payloadAsString = String(data: data, encoding: .utf8)
        }
        zmLog.debug("Callback: \(String(describing: self.callConfigCompletion))")
        self.callConfigCompletion?(payloadAsString, response.httpStatus)
        self.callConfigCompletion = nil
    }
}


extension CallingRequestStrategy : ZMContextChangeTracker, ZMContextChangeTrackerSource {
    
    public var contextChangeTrackers: [ZMContextChangeTracker] {
        return [self, self.genericMessageStrategy]
    }
    
    public func fetchRequestForTrackedObjects() -> NSFetchRequest<NSFetchRequestResult>? {
        return nil
    }
    
    public func addTrackedObjects(_ objects: Set<NSManagedObject>) {
        // nop
    }
    
    public func objectsDidChange(_ objects: Set<NSManagedObject>) {
        guard callCenter == nil else { return }
        
        for object in objects {
            if let  userClient = object as? UserClient, userClient.isSelfClient(), let clientId = userClient.remoteIdentifier, let userId = userClient.user?.remoteIdentifier {
                callCenter = WireCallCenterV3Factory.callCenter(withUserId: userId, clientId: clientId, uiMOC: managedObjectContext.zm_userInterface, flowManager: flowManager, analytics: managedObjectContext.analytics)
                callCenter?.transport = self
                break
            }
        }
    }
    
}

extension CallingRequestStrategy : ZMEventConsumer {
    
    public func processEvents(_ events: [ZMUpdateEvent], liveEvents: Bool, prefetchResult: ZMFetchRequestBatchResult?) {
        
        let serverTimeDelta = managedObjectContext.serverTimeDelta
        
        for event in events {
            guard event.type == .conversationOtrMessageAdd else { continue }
            
            if let genericMessage = ZMGenericMessage(from: event), genericMessage.hasCalling() {
                
                guard
                    let payload = genericMessage.calling.content.data(using: .utf8, allowLossyConversion: false),
                    let senderUUID = event.senderUUID(),
                    let conversationUUID = event.conversationUUID(),
                    let clientId = event.senderClientID(),
                    let eventTimestamp = event.timeStamp()
                else {
                    zmLog.error("Ignoring calling message: \(genericMessage.debugDescription)")
                    continue
                }
                
                self.zmLog.debug("received calling message")
                
                callCenter?.received(data: payload,
                                     currentTimestamp: Date().addingTimeInterval(serverTimeDelta),
                                     serverTimestamp: eventTimestamp,
                                     conversationId: conversationUUID,
                                     userId: senderUUID,
                                     clientId: clientId)
            }
        }
    }
    
}

extension CallingRequestStrategy : WireCallCenterTransport {
    
    public func send(data: Data, conversationId: UUID, userId: UUID, completionHandler: @escaping ((Int) -> Void)) {
        
        guard let dataString = String(data: data, encoding: .utf8) else {
            zmLog.error("Not sending calling messsage since it's not UTF-8")
            completionHandler(500)
            return
        }
        
        managedObjectContext.performGroupedBlock {
            guard let conversation = ZMConversation(remoteID: conversationId, createIfNeeded: false, in: self.managedObjectContext) else {
                self.zmLog.error("Not sending calling messsage since conversation doesn't exist")
                completionHandler(500)
                return
            }
            
            self.zmLog.debug("sending calling message")
            
            let genericMessage = ZMGenericMessage(callingContent: dataString, nonce: NSUUID().transportString())
            
            self.genericMessageStrategy.schedule(message: genericMessage, inConversation: conversation) { (response) in
                
                completionHandler(response.httpStatus)
                
            }
        }
    }
    
    public func requestCallConfig(completionHandler: @escaping CallConfigRequestCompletion) {
        managedObjectContext.performGroupedBlock { [unowned self] in
            self.zmLog.debug("requestCallConfig() called")
            self.callConfigCompletion = completionHandler
            
            self.callConfigRequestSync.readyForNextRequestIfNotBusy()
            RequestAvailableNotification.notifyNewRequestsAvailable(nil)
        }
    }
    
}
