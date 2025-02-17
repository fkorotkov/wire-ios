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

import Foundation
import WireDataModel

// sourcery: AutoMockable
protocol ProteusConversationParticipantsServiceInterface {

    func addParticipants(
        _ users: [ZMUser],
        to conversation: ZMConversation
    ) async throws

    func removeParticipant(
        _ user: ZMUser,
        from conversation: ZMConversation
    ) async throws

}

struct ProteusConversationParticipantsService: ProteusConversationParticipantsServiceInterface {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func addParticipants(
        _ users: [ZMUser],
        to conversation: ZMConversation
    ) async throws {
        var action = AddParticipantAction(users: users, conversation: conversation)

        do {
            try await action.perform(in: context.notificationContext)
        } catch AddParticipantAction.Failure.nonFederatingDomains(let domains) {
            throw FederationError.nonFederatingDomains(domains)
        } catch AddParticipantAction.Failure.unreachableDomains(let domains) {
            throw FederationError.unreachableDomains(domains)
        }
    }

    func removeParticipant(
        _ user: ZMUser,
        from conversation: ZMConversation
    ) async throws {
        var action = RemoveParticipantAction(user: user, conversation: conversation)
        try await action.perform(in: context.notificationContext)
    }
}
