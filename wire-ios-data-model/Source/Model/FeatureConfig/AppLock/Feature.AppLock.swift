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

public extension Feature {

    struct AppLock: Codable {

        // MARK: - Properties

        public let status: Status
        public let config: Config

        // MARK: - Life cycle

        public init(status: Feature.Status = .enabled, config: Config = .init()) {
            self.status = status
            self.config = config
        }

        // MARK: - Types

        public struct Config: Codable, Equatable {

            /// If `true` then app lock is mandatory and can not
            /// be disabled by by the user.

            public let enforceAppLock: Bool

            /// The number of seconds in the background before the
            /// app should relock.

            public let inactivityTimeoutSecs: UInt

            public init(enforceAppLock: Bool = false, inactivityTimeoutSecs: UInt = 60) {
                self.enforceAppLock = enforceAppLock
                self.inactivityTimeoutSecs = inactivityTimeoutSecs
            }

        }

    }

}
