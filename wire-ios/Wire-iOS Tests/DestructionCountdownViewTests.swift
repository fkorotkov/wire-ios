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

@testable import Wire
import XCTest

final class DestructionCountdownViewTests: BaseSnapshotTestCase {

    // MARK: - Properties

    var sut: DestructionCountdownView!

    // MARK: - tearDown

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helper method

    func prepareSut(uiInterfaceStyle: UIUserInterfaceStyle = .light) {
        sut = DestructionCountdownView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        sut.overrideUserInterfaceStyle = uiInterfaceStyle
        sut.backgroundColor = UIColor.clear
    }

    // MARK: - Snapshot Tests

    func testThatItRendersCorrectlyInInitialState() {
        // GIVEN
        prepareSut()

        // WHEN
        sut.setNeedsLayout()
        sut.layoutIfNeeded()

        // THEN
        verify(matching: sut)
    }

    func testThatItRendersCorrectly_80_Percent_Progress() {
        // GIVEN
        prepareSut()

        // WHEN
        sut.setProgress(0.8)
        sut.setNeedsLayout()
        sut.layoutIfNeeded()

        // THEN
        verify(matching: sut)
    }

    func testThatItRendersCorrectly_60_Percent_Progress() {
        // GIVEN
        prepareSut()

        // WHEN
        sut.setProgress(0.6)
        sut.setNeedsLayout()
        sut.layoutIfNeeded()

        // THEN
        verify(matching: sut)
    }

    func testThatItRendersCorrectly_50_Percent_Progress() {
        // GIVEN
        prepareSut()

        // WHEN
        sut.setProgress(0.5)
        sut.setNeedsLayout()
        sut.layoutIfNeeded()

        // THEN
        verify(matching: sut)
    }

    func testThatItRendersCorrectly_40_Percent_Progress() {
        // GIVEN
        prepareSut()

        // WHEN
        sut.setProgress(0.4)
        sut.setNeedsLayout()
        sut.layoutIfNeeded()

        // THEN
        verify(matching: sut)
    }

    func testThatItRendersCorrectly_20_Percent_Progress() {
        // GIVEN
        prepareSut()

        // WHEN
        sut.setProgress(0.2)
        sut.setNeedsLayout()
        sut.layoutIfNeeded()

        // THEN
        verify(matching: sut)
    }

    func testThatItRendersCorrectly_0_Percent_Progress() {
        // GIVEN
        prepareSut()

        // WHEN
        sut.setProgress(0)
        sut.setNeedsLayout()
        sut.layoutIfNeeded()

        // THEN
        verify(matching: sut)
    }

    func testThatItRendersCorrectly_80_Percent_Progress_in_dark_theme() {
        // GIVEN
        prepareSut(uiInterfaceStyle: .dark)

        // WHEN
        sut.setProgress(0.8)
        sut.setNeedsLayout()
        sut.layoutIfNeeded()

        // THEN
        verify(matching: sut)
    }

    // MARK: - Unit Test

    func testThatItAnimatesProgress() {
        // GIVEN
        prepareSut()

        // WHEN
        sut.startAnimating(duration: 5, currentProgress: 0.2)
        XCTAssertTrue(sut.isAnimatingProgress)
        sut.stopAnimating()

        // THEN
        XCTAssertFalse(sut.isAnimatingProgress)
    }
}
