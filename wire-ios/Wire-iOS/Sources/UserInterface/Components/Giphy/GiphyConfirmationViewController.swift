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

import FLAnimatedImage
import UIKit
import WireCommonComponents
import Ziphy

protocol GiphyConfirmationViewControllerDelegate: AnyObject {

    func giphyConfirmationViewController(_ giphyConfirmationViewController: GiphyConfirmationViewController, didConfirmImageData imageData: Data)

}

final class GiphyConfirmationViewController: UIViewController {

    typealias Giphy = L10n.Localizable.Giphy

    private let imagePreview = FLAnimatedImageView()
    private let acceptButton = ZMButton(style: .accentColorTextButtonStyle, cornerRadius: 16, fontSpec: .normalSemiboldFont)
    private let cancelButton = ZMButton(style: .secondaryTextButtonStyle, cornerRadius: 16, fontSpec: .normalSemiboldFont)
    private let buttonContainer = UIView()
    weak var delegate: GiphyConfirmationViewControllerDelegate?
    private let searchResultController: ZiphySearchResultsController?
    private let ziph: Ziph?
    private var imageData: Data?

    /// init method with optional arguments for remove dependency for testing
    ///
    /// - Parameters:
    ///   - ziph: provide nil for testing only
    ///   - previewImage: image for preview
    ///   - searchResultController: provide nil for testing only
    init(withZiph ziph: Ziph?,
         previewImage: FLAnimatedImage?,
         searchResultController: ZiphySearchResultsController?) {
        self.ziph = ziph
        self.searchResultController = searchResultController

        super.init(nibName: nil, bundle: nil)

        if let previewImage = previewImage {
            imagePreview.animatedImage = previewImage
        }

        let closeImage = StyleKitIcon.cross.makeImage(size: .tiny, color: SemanticColors.Icon.foregroundDefaultBlack)
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: closeImage,
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(GiphySearchViewController.onDismiss))

        view.backgroundColor = SemanticColors.View.backgroundDefault
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        extendedLayoutIncludesOpaqueBars = true

        let titleLabel = UILabel()
        titleLabel.font = FontSpec.headerSemiboldFont.font!
        titleLabel.textColor = SemanticColors.Label.textDefault
        titleLabel.text = title
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel

        view.backgroundColor = .black
        acceptButton.isEnabled = false
        acceptButton.setTitle(Giphy.confirm.capitalized, for: .normal)
        acceptButton.addTarget(self, action: #selector(GiphyConfirmationViewController.onAccept), for: .touchUpInside)
        cancelButton.setTitle(Giphy.cancel.capitalized, for: .normal)
        cancelButton.addTarget(self, action: #selector(GiphyConfirmationViewController.onCancel), for: .touchUpInside)

        imagePreview.contentMode = .scaleAspectFit

        view.addSubview(imagePreview)
        view.addSubview(buttonContainer)

        [cancelButton, acceptButton].forEach(buttonContainer.addSubview)

        configureConstraints()
        fetchImage()
    }

    func fetchImage() {
        guard let ziph = ziph, let searchResultController = searchResultController else { return }

        searchResultController.fetchImageData(for: ziph, imageType: .downsized) { [weak self] result in
            guard case let .success(imageData) = result else {
                return
            }

            self?.imagePreview.animatedImage = FLAnimatedImage(animatedGIFData: imageData)
            self?.imageData = imageData
            self?.acceptButton.isEnabled = true
        }
    }

    @objc
    private func onDismiss() {
        dismiss(animated: true, completion: nil)
    }

    @objc
    private func onCancel() {
        _ = navigationController?.popViewController(animated: true)
    }

    @objc
    private func onAccept() {
        if let imageData = imageData {
            delegate?.giphyConfirmationViewController(self, didConfirmImageData: imageData)
        }
    }

    private func configureConstraints() {

        let widthConstraint = buttonContainer.widthAnchor.constraint(equalToConstant: 476)

        widthConstraint.priority = .init(700)

        [
            imagePreview,
            buttonContainer,
            cancelButton,
            acceptButton
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            imagePreview.leadingAnchor.constraint(equalTo: view.safeLeadingAnchor),
            imagePreview.trailingAnchor.constraint(equalTo: view.safeTrailingAnchor),
            imagePreview.topAnchor.constraint(equalTo: safeTopAnchor),
            imagePreview.bottomAnchor.constraint(equalTo: buttonContainer.topAnchor, constant: -20),

            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            cancelButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            cancelButton.leftAnchor.constraint(equalTo: buttonContainer.leftAnchor),
            cancelButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),

            acceptButton.heightAnchor.constraint(equalToConstant: 40),
            acceptButton.rightAnchor.constraint(equalTo: buttonContainer.rightAnchor),
            acceptButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            acceptButton.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),

            cancelButton.widthAnchor.constraint(equalTo: acceptButton.widthAnchor),
            cancelButton.rightAnchor.constraint(equalTo: acceptButton.leftAnchor, constant: -16),

            buttonContainer.leftAnchor.constraint(greaterThanOrEqualTo: view.leftAnchor, constant: 32),
            buttonContainer.rightAnchor.constraint(lessThanOrEqualTo: view.rightAnchor, constant: -32),
            buttonContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32),
            widthConstraint,
            buttonContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
}
