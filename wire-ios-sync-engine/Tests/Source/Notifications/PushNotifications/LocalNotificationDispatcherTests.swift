//
// Wire
// Copyright (C) 2024 Wire Swiss GmbH
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

import UserNotifications
import XCTest

@testable import WireSyncEngine

final class LocalNotificationDispatcherTests: DatabaseTest {

    typealias ZMLocalNotification = WireSyncEngine.ZMLocalNotification

    var sut: LocalNotificationDispatcher!
    var conversation1: ZMConversation!
    var conversation2: ZMConversation!

    var notificationCenter: UserNotificationCenterMock!

    var scheduledRequests: [UNNotificationRequest] {
        return self.notificationCenter.scheduledRequests
    }

    var user1: ZMUser!
    var user2: ZMUser!

    var selfUser: ZMUser {
        return ZMUser.selfUser(in: self.syncMOC)
    }

    override func setUp() {
        super.setUp()
        self.notificationCenter = UserNotificationCenterMock()
        self.syncMOC.performAndWait {
            self.sut = LocalNotificationDispatcher(in: self.syncMOC)
        }
        self.sut.notificationCenter = self.notificationCenter

        [self.sut.eventNotifications,
         self.sut.failedMessageNotifications,
         self.sut.callingNotifications].forEach { $0.notificationCenter = notificationCenter }

        syncMOC.performGroupedBlockAndWait {
            self.user1 = ZMUser.insertNewObject(in: self.syncMOC)
            self.user2 = ZMUser.insertNewObject(in: self.syncMOC)
            self.user1.remoteIdentifier = UUID.create()
            self.user1.name = "User 1"
            self.user2.remoteIdentifier = UUID.create()
            self.user2.name = "User 2"
            self.conversation1 = ZMConversation.insertNewObject(in: self.syncMOC)
            self.conversation1.userDefinedName = "Conversation 1"
            self.conversation2 = ZMConversation.insertNewObject(in: self.syncMOC)
            self.conversation2.userDefinedName = "Conversation 2"
            [self.conversation1!, self.conversation2!].forEach {
                $0.conversationType = .group
                $0.remoteIdentifier = UUID.create()
                $0.addParticipantAndUpdateConversationState(user: self.user1, role: nil)
            }
            self.conversation2.addParticipantAndUpdateConversationState(user: self.user2, role: nil)

            self.selfUser.remoteIdentifier = UUID.create()
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

    }

    override func tearDown() {
        self.notificationCenter = nil
        self.user1 = nil
        self.user2 = nil
        self.conversation1 = nil
        self.conversation2 = nil
        self.sut = nil
        super.tearDown()
    }
}

extension LocalNotificationDispatcherTests {

    func testThatItCreatesNotificationFromMessagesIfNotActive() {
        // GIVEN
        let text = UUID.create().transportString()
        syncMOC.performGroupedBlockAndWait {
            let event = self.createUpdateEvent(UUID.create(), conversationID: self.conversation1.remoteIdentifier!, genericMessage: GenericMessage(content: Text(content: text)), senderID: self.user1.remoteIdentifier)

            // WHEN
            self.sut.processEventsWhileInBackground([event])
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        XCTAssertEqual(self.sut.eventNotifications.notifications.count, 1)
        XCTAssertEqual(self.scheduledRequests.count, 1)

        guard
            let note = self.sut.eventNotifications.notifications.first,
            let request = self.scheduledRequests.first
        else { return XCTFail() }

        XCTAssertTrue(note.body.contains(text))
        XCTAssertEqual(note.body, request.content.body)
        XCTAssertEqual(note.id.uuidString, request.identifier)
    }

    func testThatItCreatesNotificationFromSystemMessagesIfNotActive() {
        syncMOC.performGroupedBlockAndWait {
            // GIVEN
            let messageTimer = MessageDestructionTimeoutValue.fiveMinutes
            let payload: [String: Any] = [
                "id": UUID.create().transportString(),
                "from": self.user1.remoteIdentifier.transportString(),
                "conversation": self.conversation1.remoteIdentifier!.transportString(),
                "time": Date().transportString(),
                "data": ["message_timer": messageTimer.rawValue * 1000],
                "type": "conversation.message-timer-update"
            ]
            let event = ZMUpdateEvent(fromEventStreamPayload: payload as ZMTransportData, uuid: UUID.create())!
            event.source = .pushNotification

            // WHEN
            self.sut.processEventsWhileInBackground([event])
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        XCTAssertEqual(self.sut.eventNotifications.notifications.count, 1)
        XCTAssertEqual(self.scheduledRequests.count, 1)

        guard
            let note = self.sut.eventNotifications.notifications.first,
            let request = self.scheduledRequests.first
        else { return XCTFail() }

        XCTAssertTrue(note.body.contains("User 1 set the message timer to"))
        XCTAssertEqual(note.body, request.content.body)
        XCTAssertEqual(note.id.uuidString, request.identifier)
    }

    func testThatItAddsNotificationOfDifferentConversationsToTheList() {
        syncMOC.performGroupedBlock {
            // GIVEN
            let event1 = self.createUpdateEvent(UUID.create(), conversationID: self.conversation1.remoteIdentifier!, genericMessage: GenericMessage(content: Text(content: "foo1")), senderID: self.user1.remoteIdentifier)
            let event2 = self.createUpdateEvent(UUID.create(), conversationID: self.conversation2.remoteIdentifier!, genericMessage: GenericMessage(content: Text(content: "boo2")), senderID: self.user2.remoteIdentifier)

            // WHEN
            self.sut.processEventsWhileInBackground([event1, event2])
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        syncMOC.performAndWait { [self] in
            // THEN
            XCTAssertEqual(self.scheduledRequests.count, 2)
            let userInfos = self.scheduledRequests.map { NotificationUserInfo(storage: $0.content.userInfo) }
            XCTAssertEqual(userInfos[0].conversation(in: self.syncMOC), self.conversation1)
            XCTAssertEqual(userInfos[1].conversation(in: self.syncMOC), self.conversation2)
        }
    }

    func testThatItDoesNotCreateANotificationForAnUnsupportedEventType() {
        syncMOC.performAndWait {
            // GIVEN
            let event = self.event(withPayload: nil, type: .conversationTyping, in: self.conversation1, user: self.user1)

            // WHEN
            self.sut.didReceive(events: [event], conversationMap: [:])

            // THEN
            XCTAssertEqual(self.scheduledRequests.count, 0)
        }
    }

    func testThatWhenFailingAMessageItSchedulesANotification() {
        self.syncMOC.performGroupedBlockAndWait {
            // GIVEN
            let message = try! self.conversation1.appendText(content: "bar") as! ZMClientMessage
            message.sender = self.user1

            // WHEN
            self.sut.didFailToSend(message)

            // THEN
            XCTAssertEqual(self.scheduledRequests.count, 1)
        }
    }

    func testThatItCancelsAllNotificationsForFailingMessagesWhenCancelingAllNotifications() {
        self.syncMOC.performGroupedBlockAndWait { [self] in
            // GIVEN
            let note1 = ZMLocalNotification(expiredMessageIn: conversation1, moc: syncMOC)!
            let note2 = ZMLocalNotification(expiredMessageIn: conversation1, moc: syncMOC)!
            self.sut.eventNotifications.addObject(note1)
            self.sut.failedMessageNotifications.addObject(note2)

            // WHEN
            self.sut.cancelAllNotifications()

            // THEN
            XCTAssertEqual(self.notificationCenter.removedNotifications, Set([note1.id.uuidString, note2.id.uuidString]))
        }
    }

    func testThatItCancelsNotificationsForFailingMessagesWhenCancelingNotificationsForASpecificConversation() {
        self.syncMOC.performGroupedBlockAndWait { [self] in
            // GIVEN
            let note1 = ZMLocalNotification(expiredMessageIn: conversation1, moc: syncMOC)!
            let note2 = ZMLocalNotification(expiredMessageIn: conversation2, moc: syncMOC)!
            let note3 = ZMLocalNotification(expiredMessageIn: conversation1, moc: syncMOC)!
            let note4 = ZMLocalNotification(expiredMessageIn: conversation2, moc: syncMOC)!
            self.sut.eventNotifications.addObject(note1)
            self.sut.eventNotifications.addObject(note2)
            self.sut.failedMessageNotifications.addObject(note3)
            self.sut.failedMessageNotifications.addObject(note4)

            // WHEN
            self.sut.cancelNotification(for: self.conversation1)

            // THEN
            XCTAssertEqual(self.notificationCenter.removedNotifications, Set([note1.id.uuidString, note3.id.uuidString]))
        }
    }

    func testThatItCancelsReadNotificationsIfTheLastReadChanges() {
        var note1: ZMLocalNotification!
        var note2: ZMLocalNotification!

        self.syncMOC.performGroupedBlockAndWait { [self] in
            // GIVEN
            let message = try! conversation1.appendText(content: "foo") as! ZMClientMessage
            message.sender = user1
            note1 = ZMLocalNotification(expiredMessage: message, moc: syncMOC)!
            note2 = ZMLocalNotification(expiredMessageIn: self.conversation1, moc: syncMOC)!
            sut.eventNotifications.addObject(note1)
            sut.eventNotifications.addObject(note2)
            conversation1.lastServerTimeStamp = Date.distantFuture
            syncMOC.saveOrRollback()

            // WHEN
            let conversationOnUI = uiMOC.object(with: conversation1.objectID) as? ZMConversation
            conversationOnUI?.markAsRead()
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        self.syncMOC.performGroupedBlockAndWait { [self] in
            // THEN
            XCTAssertEqual(self.notificationCenter.removedNotifications, Set([note1.id.uuidString, note2.id.uuidString]))
        }
    }

    func testThatItSchedulesADefaultNotificationIfContentShouldNotBeVisible() {
        self.syncMOC.performGroupedBlockAndWait { [self] in
            // GIVEN
            self.syncMOC.setPersistentStoreMetadata(NSNumber(value: true), key: LocalNotificationDispatcher.ZMShouldHideNotificationContentKey)
            self.syncMOC.saveOrRollback()

            let event = createUpdateEvent(UUID.create(), conversationID: self.conversation1.remoteIdentifier!, genericMessage: GenericMessage(content: Text(content: "foo")), senderID: self.user1.remoteIdentifier)

            // WHEN
            self.sut.processEventsWhileInBackground([event])
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        XCTAssertEqual(self.scheduledRequests.count, 1)
        XCTAssertEqual(self.scheduledRequests[0].content.body, "New message")
        XCTAssertEqual(self.scheduledRequests[0].content.sound, UNNotificationSound(named: convertToUNNotificationSoundName("default")))

    }

    func testThatItDoesNotCreateNotificationForTwoMessageEventsWithTheSameNonce() {
        var event: ZMUpdateEvent!
        self.syncMOC.performGroupedBlockAndWait { [self] in
            // GIVEN
            event = createUpdateEvent(UUID.create(), conversationID: self.conversation1.remoteIdentifier!, genericMessage: GenericMessage(content: Text(content: "foobar")), senderID: self.user1.remoteIdentifier)

            // WHEN
            self.sut.processEventsWhileInBackground([event])
        }
            XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

            // THEN
            XCTAssertEqual(self.sut.eventNotifications.notifications.count, 1)
            XCTAssertEqual(self.scheduledRequests.count, 1)

            // WHEN
        self.syncMOC.performGroupedBlockAndWait { [self] in
            self.sut.processEventsWhileInBackground([event])
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        XCTAssertEqual(self.sut.eventNotifications.notifications.count, 1)
        XCTAssertEqual(self.scheduledRequests.count, 1)

    }

    func testThatItDoesNotCreateNotificationForFileUploadEventsWithTheSameNonce() {
        var event: ZMUpdateEvent!
        self.syncMOC.performGroupedBlockAndWait { [self] in
            // GIVEN
            let url = Bundle(for: LocalNotificationDispatcherTests.self).url(forResource: "video", withExtension: "mp4")
            let audioMetadata = ZMAudioMetadata(fileURL: url!, duration: 100)
            event = createUpdateEvent(UUID.create(), conversationID: self.conversation1.remoteIdentifier!, genericMessage: GenericMessage(content: WireProtos.Asset(audioMetadata)), senderID: self.user1.remoteIdentifier)

            // WHEN
            self.sut.processEventsWhileInBackground([event])
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        XCTAssertEqual(self.sut.eventNotifications.notifications.count, 1)
        XCTAssertEqual(self.scheduledRequests.count, 1)

        self.syncMOC.performGroupedBlockAndWait { [self] in
            // WHEN
            self.sut.processEventsWhileInBackground([event])
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        XCTAssertEqual(self.sut.eventNotifications.notifications.count, 1)
        XCTAssertEqual(self.scheduledRequests.count, 1)

    }

    func testThatItCreatesNotificationForSelfGroupParticipation() {
        // GIVEN
        var payload: [String: Any]!
        var text = ""
        syncMOC.performAndWait {

            // notification content
            text = "\(self.user1.name!) added you"
            payload = [
                "from": self.user1.remoteIdentifier.transportString(),
                "conversation": self.conversation1.remoteIdentifier!.transportString(),
                "time": Date().transportString(),
                "data": [
                    "user_ids": [self.selfUser.remoteIdentifier.transportString()],
                    "users": ["id": self.selfUser.remoteIdentifier.transportString(),
                              "conversation_role": "wire_admin"]
                ],
                "type": "conversation.member-join"
            ]

        }
        let event = ZMUpdateEvent(fromEventStreamPayload: payload as ZMTransportData, uuid: UUID())!
        event.source = .pushNotification

        // WHEN
        syncMOC.performGroupedBlock {
            self.sut.processEventsWhileInBackground([event])
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        XCTAssertEqual(self.scheduledRequests.count, 1)
        XCTAssertTrue(self.scheduledRequests.first!.content.body.contains(text))
    }

    func testThatItDoesNotCreateNotificationForOtherGroupParticipation() {
        var event: ZMUpdateEvent!
        syncMOC.performAndWait {
            // GIVEN
            let payload: [String: Any] = [
                "from": self.user1.remoteIdentifier.transportString(),
                "conversation": self.conversation1.remoteIdentifier!.transportString(),
                "time": Date().transportString(),
                "data": [
                    "user_ids": [self.user2.remoteIdentifier.transportString()],
                    "users": ["id": self.user2.remoteIdentifier.transportString(),
                              "conversation_role": "wire_admin"]
                ],
                "type": "conversation.member-join"
            ]
            event = ZMUpdateEvent(fromEventStreamPayload: payload as ZMTransportData, uuid: UUID())!
            event.source = .pushNotification
        }
        // WHEN
        syncMOC.performGroupedBlock {
            self.sut.processEventsWhileInBackground([event])
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        XCTAssertEqual(self.scheduledRequests.count, 0)
    }

    func testThatNotifyAvailabilityBehaviourChangedIfNeededSchedulesNotification_WhenNeedsToNotifyAvailabilityBehaviourChangeIsSet() {
        syncMOC.performAndWait {
            // given
            selfUser.availability = .away
            selfUser.needsToNotifyAvailabilityBehaviourChange = [.notification]

            // when
            sut.notifyAvailabilityBehaviourChangedIfNeeded()

            // then
            XCTAssertEqual(self.notificationCenter.scheduledRequests.count, 1)
            XCTAssertEqual(selfUser.needsToNotifyAvailabilityBehaviourChange, [])
        }
    }

    func testThatNotifyAvailabilityBehaviourChangedIfNeededDoesNotScheduleNotification_WhenneedsToNotifyAvailabilityBehaviourChangeIsNotSet() {
        syncMOC.performAndWait {
            // given
            selfUser.needsToNotifyAvailabilityBehaviourChange = []

            // when
            sut.notifyAvailabilityBehaviourChangedIfNeeded()

            // then
            XCTAssertEqual(self.notificationCenter.scheduledRequests.count, 0)
        }
    }

    // MARK: Updating unread count

    func testThatEstimatedUnreadCountIsIncreased_WhenProcessingTextMessage() {
        syncMOC.performGroupedBlock {
            // GIVEN
            let text = UUID.create().transportString()
            let event = self.createUpdateEvent(UUID.create(), conversationID: self.conversation1.remoteIdentifier!, genericMessage: GenericMessage(content: Text(content: text)), senderID: self.user1.remoteIdentifier)

            // WHEN
            self.sut.processEventsWhileInBackground([event])
        }
            XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

            // THEN
        syncMOC.performAndWait {
            XCTAssertEqual(self.conversation1.estimatedUnreadCount, 1)
            XCTAssertEqual(self.conversation1.estimatedUnreadSelfMentionCount, 0)
            XCTAssertEqual(self.conversation1.estimatedUnreadSelfReplyCount, 0)
        }
    }

    func testThatEstimatedUnreadMentionCountIsIncreased_WhenProcessingTextMessageWhichMentionsSelfUser() {
        syncMOC.performGroupedAndWait { [self] _ in
            // GIVEN
            let text = UUID.create().transportString()
            let selfUserMention = Mention(range: NSRange(), user: selfUser)
            let event = createUpdateEvent(UUID.create(), conversationID: self.conversation1.remoteIdentifier!, genericMessage: GenericMessage(content: Text(content: text, mentions: [selfUserMention])), senderID: self.user1.remoteIdentifier)

            // WHEN
            self.sut.processEventsWhileInBackground([event])
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

            // THEN
        syncMOC.performAndWait {
            XCTAssertEqual(self.conversation1.estimatedUnreadCount, 1)
            XCTAssertEqual(self.conversation1.estimatedUnreadSelfMentionCount, 1)
            XCTAssertEqual(self.conversation1.estimatedUnreadSelfReplyCount, 0)
        }
    }

    func testThatEstimatedUnreadMentionCountIsIncreased_WhenProcessingTextMessageWhichRepliesToSelfUser() {
        syncMOC.performGroupedAndWait { [self] _ in
            // GIVEN
            let message = try! conversation1.appendText(content: "Hello") as! ZMOTRMessage
            let text = UUID.create().transportString()
            let event = createUpdateEvent(UUID.create(), conversationID: self.conversation1.remoteIdentifier!, genericMessage: GenericMessage(content: Text(content: text, replyingTo: message)), senderID: self.user1.remoteIdentifier)

            // WHEN
            self.sut.processEventsWhileInBackground([event])
        }
            XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

            // THEN
        syncMOC.performAndWait {
            XCTAssertEqual(self.conversation1.estimatedUnreadCount, 1)
            XCTAssertEqual(self.conversation1.estimatedUnreadSelfMentionCount, 0)
            XCTAssertEqual(self.conversation1.estimatedUnreadSelfReplyCount, 1)
        }
    }
}

// MARK: - Helpers
extension LocalNotificationDispatcherTests {

    func payloadForEncryptedOTRMessage(text: String, nonce: UUID) -> [String: Any] {
        let message = GenericMessage(content: Text(content: text), nonce: nonce)
        return self.payloadForOTRAsset(with: message)
    }

    func payloadForOTRAsset(with message: GenericMessage) -> [String: Any] {
        return [
            "data": [
                "info": try? message.serializedData().base64String()
            ],
            "conversation": self.conversation1.remoteIdentifier!.transportString(),
            "type": EventConversationAddOTRAsset,
            "time": Date().transportString()
        ]
    }

    func payloadForOTRMessage(with message: GenericMessage) -> [String: Any] {
        return [
            "data": [
                "text": try? message.serializedData().base64String()
            ],
            "conversation": self.conversation1.remoteIdentifier!.transportString(),
            "type": EventConversationAddOTRAsset,
            "time": Date().transportString()
        ]
    }

    func createUpdateEvent(_ nonce: UUID, conversationID: UUID, genericMessage: GenericMessage, senderID: UUID = UUID.create()) -> ZMUpdateEvent {
        let payload: [String: Any] = [
            "id": UUID.create().transportString(),
            "conversation": conversationID.transportString(),
            "from": senderID.transportString(),
            "time": Date().transportString(),
            "data": ["text": try? genericMessage.serializedData().base64String()],
            "type": "conversation.otr-message-add"
        ]

        return ZMUpdateEvent(uuid: nonce,
                             payload: payload,
                             transient: false,
                             decrypted: true,
                             source: .pushNotification)!
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToUNNotificationSoundName(_ input: String) -> UNNotificationSoundName {
    return UNNotificationSoundName(rawValue: input)
}
