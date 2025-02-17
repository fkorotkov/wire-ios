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
@testable import WireSyncEngine
import XCTest

final class AppLockIntegrationTests: IntegrationTest {

    private var appLock: MockAppLock!

    override func setUp() {
        super.setUp()
        createSelfUserAndConversation()
        XCTAssertTrue(login())

        appLock = MockAppLock()
        userSession?.appLockController = appLock
        appLock.delegate = userSession
    }

    override func tearDown() {
        appLock = nil
        super.tearDown()
    }

    func testOpeningAppLockUnlocksUserSession() {
        // Given
        appLock.isLocked = true
        XCTAssertEqual(userSession!.lock, .screen)

        // When
        appLock.isLocked = false
        appLock.delegate?.appLockDidOpen(appLock)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // Then
        XCTAssertNil(userSession!.lock)
    }

}
