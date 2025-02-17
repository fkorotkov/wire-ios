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

import avs
import UIKit
import WireSyncEngine

final class SelfCallParticipantView: BaseCallParticipantView {

    var previewView = AVSVideoPreview()

    override var stream: Stream {
        didSet {
            guard stream.callParticipantState.videoState != self.videoState else { return }
            updateCaptureState(with: stream.callParticipantState.videoState)
        }
    }

    override var videoView: AVSVideoViewProtocol? {
        previewView
    }

    private var videoState: VideoState?

    deinit {
        stopCapture()
    }

    override func setupViews() {
        super.setupViews()
        previewView.backgroundColor = .clear
        previewView.translatesAutoresizingMaskIntoConstraints = false

        let scalableView = ScalableView(isScalingEnabled: shouldEnableScaling)
        scalableView.addSubview(previewView)
        insertSubview(scalableView, belowSubview: userDetailsView)
        self.scalableView = scalableView
    }

    override func createConstraints() {
        super.createConstraints()

        [previewView, scalableView].forEach {
            $0?.translatesAutoresizingMaskIntoConstraints = false
            $0?.fitIn(view: self)
        }
    }

    override func updateUserDetails() {
        userDetailsView.microphoneIconStyle = MicrophoneIconStyle(
            state: stream.microphoneState,
            shouldPulse: stream.activeSpeakerState.isSpeakingNow
        )
        userDetailsView.callState = stream.callParticipantState

        guard let name = stream.user?.name else { return }
        userDetailsView.name = name + L10n.Localizable.UserCell.Title.youSuffix
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window != nil {
            updateCaptureState(with: stream.videoState)
        }
    }

    func updateCaptureState(with newVideoState: VideoState?) {
        guard newVideoState != self.videoState else { return }

        if newVideoState == .some(.started) {
            startCapture()
        } else {
            stopCapture()
        }
        self.videoState = newVideoState
    }

    func startCapture() {
        previewView.startVideoCapture()
    }

    func stopCapture() {
        previewView.stopVideoCapture()
    }

}
