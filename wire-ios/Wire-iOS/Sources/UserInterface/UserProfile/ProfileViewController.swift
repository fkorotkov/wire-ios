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

import UIKit
import WireDataModel
import WireSyncEngine

private let zmLog = ZMSLog(tag: "ProfileViewController")

enum ProfileViewControllerTabBarIndex: Int {
    case details = 0
    case devices
}

protocol ProfileViewControllerDelegate: AnyObject {
    func profileViewController(_ controller: ProfileViewController?, wantsToNavigateTo conversation: ZMConversation)
}

protocol BackButtonTitleDelegate: AnyObject {
    func suggestedBackButtonTitle(for controller: ProfileViewController?) -> String?
}

extension ZMConversationType {
    var profileViewControllerContext: ProfileViewControllerContext {
        switch self {
        case .group:
            return .groupConversation
        default:
            return .oneToOneConversation
        }
    }
}

final class ProfileViewController: UIViewController {
    let viewModel: ProfileViewControllerViewModel
    weak var viewControllerDismisser: ViewControllerDismisser?

    private let profileFooterView = ProfileFooterView()
    private let incomingRequestFooter = IncomingRequestFooterView()
    private let securityLevelView = SecurityLevelView()
    private var incomingRequestFooterBottomConstraint: NSLayoutConstraint?

    private var tabsController: TabBarController?

    var delegate: ProfileViewControllerDelegate? {
        get {
            return viewModel.delegate
        }
        set {
            viewModel.delegate = newValue
        }
    }

    // MARK: - init

    convenience init(
        user: UserType,
        viewer: UserType,
        conversation: ZMConversation? = nil,
        context: ProfileViewControllerContext? = nil,
        classificationProvider: SecurityClassificationProviding? = ZMUserSession.shared(),
        viewControllerDismisser: ViewControllerDismisser? = nil,
        userSession: UserSession
    ) {
        let profileViewControllerContext: ProfileViewControllerContext
        if let context = context {
            profileViewControllerContext = context
        } else {
            profileViewControllerContext = conversation?.conversationType.profileViewControllerContext ?? .oneToOneConversation
        }

        let viewModel = ProfileViewControllerViewModel(
            user: user,
            conversation: conversation,
            viewer: viewer,
            context: profileViewControllerContext,
            classificationProvider: classificationProvider,
            userSession: userSession
        )

        self.init(viewModel: viewModel)

        setupKeyboardFrameNotification()

        self.viewControllerDismisser = viewControllerDismisser
    }

    required init(viewModel: ProfileViewControllerViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        let user = viewModel.user

        user.refreshData()
        if user.isTeamMember {
            user.refreshMembership()
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Header
    private func setupHeader() {
        securityLevelView.configure(with: viewModel.classification)
        view.addSubview(securityLevelView)
    }

    // MARK: - Actions
    private func bringUpConversationCreationFlow() {

        let controller = ConversationCreationController(
            preSelectedParticipants: viewModel.userSet,
            userSession: viewModel.userSession
        )
        controller.delegate = self

        let wrappedController = controller.wrapInNavigationController()
        wrappedController.modalPresentationStyle = .formSheet
        present(wrappedController, animated: true)
    }

    private func bringUpCancelConnectionRequestSheet(from targetView: UIView) {
        let user = viewModel.user

        let controller = UIAlertController.cancelConnectionRequest(for: user) { canceled in
            if !canceled {
                self.viewModel.cancelConnectionRequest {
                    self.returnToPreviousScreen()
                }
            }
        }

        presentAlert(controller, targetView: targetView)
    }

    override func loadView() {
        super.loadView()

        viewModel.viewModelDelegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.setDynamicFontLabel(title: L10n.Localizable.Profile.Details.title)

        view.addSubview(profileFooterView)
        view.addSubview(incomingRequestFooter)

        view.backgroundColor = SemanticColors.View.backgroundDefault

        setupHeader()
        setupTabsController()
        setupConstraints()
        updateFooterViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationItems()
        UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: navigationItem.titleView)
    }

    // MARK: - Keyboard frame observer

    private func setupKeyboardFrameNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameDidChange(notification:)),
            name: UIResponder.keyboardDidChangeFrameNotification,
            object: nil
        )
    }

    @objc
    private func keyboardFrameDidChange(notification: Notification) {
        updatePopoverFrame()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return wr_supportedInterfaceOrientations
    }

    private func setupProfileDetailsViewController() -> ProfileDetailsViewController {
        // swiftlint:disable todo_requires_jira_link
        // TODO: Pass the whole view Model/stuct/context
        // swiftlint:enable todo_requires_jira_link
        let profileDetailsViewController = ProfileDetailsViewController(
            user: viewModel.user,
            viewer: viewModel.viewer,
            conversation: viewModel.conversation,
            context: viewModel.context,
            userSession: viewModel.userSession
        )
        profileDetailsViewController.title = L10n.Localizable.Profile.Details.title

        return profileDetailsViewController
    }

    private func setupTabsController() {
        var viewControllers = [UIViewController]()

        let profileDetailsViewController = setupProfileDetailsViewController()
        viewControllers.append(profileDetailsViewController)

        if viewModel.hasUserClientListTab {
            let userClientListViewController = UserClientListViewController(
                user: viewModel.user,
                userSession: viewModel.userSession,
                contextProvider: viewModel.userSession as? ContextProvider,
                mlsGroupId: viewModel.conversation?.mlsGroupID
            )
            viewControllers.append(userClientListViewController)
        }

        tabsController = TabBarController(viewControllers: viewControllers)
        if viewModel.context == .deviceList, tabsController?.viewControllers.count > 1 {
            tabsController?.selectIndex(ProfileViewControllerTabBarIndex.devices.rawValue, animated: false)
        }
        addToSelf(tabsController!)
        tabsController?.isTabBarHidden = viewControllers.count < 2
        tabsController?.view.backgroundColor = SemanticColors.View.backgroundDefault
    }

    // MARK: - Constraints

    private func setupConstraints() {
        guard let tabsView = tabsController?.view else { fatal("Tabs view is not created") }

        let securityBannerHeight: CGFloat = securityLevelView.isHidden ? 0 : 24

        [securityLevelView, tabsView, profileFooterView, incomingRequestFooter].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        let incomingRequestFooterBottomConstraint = incomingRequestFooter.bottomAnchor.constraint(equalTo: view.bottomAnchor).withPriority(.defaultLow)

        NSLayoutConstraint.activate([
            securityLevelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            securityLevelView.topAnchor.constraint(equalTo: view.topAnchor),
            securityLevelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            securityLevelView.heightAnchor.constraint(equalToConstant: securityBannerHeight),

            tabsView.topAnchor.constraint(equalTo: securityLevelView.bottomAnchor),

            tabsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            profileFooterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            profileFooterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            profileFooterView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            incomingRequestFooter.bottomAnchor.constraint(equalTo: profileFooterView.topAnchor),
            incomingRequestFooter.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            incomingRequestFooter.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            incomingRequestFooterBottomConstraint
        ])
        self.incomingRequestFooterBottomConstraint = incomingRequestFooterBottomConstraint
    }
}

extension ProfileViewController: ViewControllerDismisser {
    func dismiss(viewController: UIViewController, completion: (() -> Void)?) {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Footer View

extension ProfileViewController: ProfileFooterViewDelegate, IncomingRequestFooterViewDelegate {

    func footerView(_ footerView: IncomingRequestFooterView, didRespondToRequestWithAction action: IncomingConnectionAction) {
        switch action {
        case .accept:
            viewModel.acceptConnectionRequest()
        case .ignore:
            viewModel.ignoreConnectionRequest()
        }

    }

    func footerView(_ footerView: ProfileFooterView, shouldPerformAction action: ProfileAction) {
        performAction(action, targetView: footerView.leftButton)
    }

    func footerView(_ footerView: ProfileFooterView,
                    shouldPresentMenuWithActions actions: [ProfileAction]) {
        let actionSheet = UIAlertController(title: nil,
                                            message: nil,
                                            preferredStyle: .actionSheet)

        actions.map { buildProfileAction($0, footerView: footerView) }
            .forEach(actionSheet.addAction)
        actionSheet.addAction(.cancel())
        presentAlert(actionSheet, targetView: footerView)
    }

    private func buildProfileAction(_ action: ProfileAction,
                                    footerView: ProfileFooterView) -> UIAlertAction {
        return UIAlertAction(title: action.buttonText,
                             style: .default) { _ in
            self.performAction(action, targetView: footerView)
        }
    }

    private func performAction(_ action: ProfileAction, targetView: UIView) {
        switch action {
        case .createGroup:
            bringUpConversationCreationFlow()
        case .mute(let isMuted):
            viewModel.updateMute(enableNotifications: isMuted)
        case .manageNotifications:
            presentNotificationsOptions(from: targetView)
        case .archive:
            viewModel.archiveConversation()
        case .deleteContents:
            presentDeleteConfirmationPrompt(from: targetView)
        case let .block(isBlocked):
            if isBlocked {
                handleBlockAndUnblock()
            } else {
                presentBlockActionSheet(from: targetView)
            }
        case .openOneToOne:
            viewModel.openOneToOneConversation()
        case .removeFromGroup:
            presentRemoveUserMenuSheetController(from: targetView)
        case .connect:
            viewModel.sendConnectionRequest()
        case .cancelConnectionRequest:
            bringUpCancelConnectionRequestSheet(from: targetView)
        case .openSelfProfile:
            openSelfProfile()
        case .duplicateUser:
            duplicateUser()
        case .duplicateTeam:
            duplicateTeam()
        }
    }

    private func openSelfProfile() {
        // Do not reveal list view for iPad regular mode
        let leftViewControllerRevealed: Bool
        if let presentingViewController = presentingViewController {
            leftViewControllerRevealed = !presentingViewController.isIPadRegular(device: UIDevice.current)
        } else {
            leftViewControllerRevealed = true
        }

        dismiss(animated: true) { [weak self] in
            self?.viewModel.transitionToListAndEnqueue(leftViewControllerRevealed: leftViewControllerRevealed) {
                ZClientViewController.shared?.conversationListViewController.topBarViewController.presentSettings()
            }
        }
    }

    /// Presents an alert as a popover if needed.
    private func presentAlert(_ alert: UIAlertController, targetView: UIView) {
        alert.popoverPresentationController?.sourceView = targetView
        alert.popoverPresentationController?.sourceRect = targetView.bounds.insetBy(dx: 8, dy: 8)
        alert.popoverPresentationController?.permittedArrowDirections = .down
        present(alert, animated: true)
    }

    // MARK: Legal Hold

    private var legalholdItem: UIBarButtonItem {
        let item = UIBarButtonItem(icon: .legalholdactive, target: self, action: #selector(presentLegalHoldDetails))
        item.setLegalHoldAccessibility()
        item.tintColor = SemanticColors.Icon.foregroundDefaultRed
        return item
    }

    @objc
    private func presentLegalHoldDetails() {
        let user = viewModel.user
        LegalHoldDetailsViewController.present(in: self, user: user, userSession: viewModel.userSession)
    }

    // MARK: Block

    private func presentBlockActionSheet(from targetView: UIView) {
        let controller = UIAlertController(title: viewModel.blockTitle, message: nil, preferredStyle: .actionSheet)
        viewModel.allBlockResult.map { $0.action(handleBlockActions) }.forEach(controller.addAction)
        presentAlert(controller, targetView: targetView)
    }

    private func handleBlockActions(_ result: BlockResult) {
        guard case .block = result else { return }
        handleBlockAndUnblock()
    }

    private func handleBlockAndUnblock() {
        viewModel.handleBlockAndUnblock()
        updateFooterViews()
    }

    // MARK: Notifications

    private func presentNotificationsOptions(from targetView: UIView) {
        guard let conversation = viewModel.conversation else { return }

        let title = "\(conversation.displayNameWithFallback) • \(NotificationResult.title)"
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        NotificationResult.allCases.map { $0.action(for: conversation, handler: viewModel.handleNotificationResult) }.forEach(controller.addAction)
        presentAlert(controller, targetView: targetView)
    }

    // MARK: Delete Contents

    private func presentDeleteConfirmationPrompt(from targetView: UIView) {
        guard let conversation = viewModel.conversation else { return }

        let controller = UIAlertController(title: ClearContentResult.title, message: nil, preferredStyle: .actionSheet)
        ClearContentResult.options(for: conversation).map { $0.action(viewModel.handleDeleteResult) }.forEach(controller.addAction)
        presentAlert(controller, targetView: targetView)
    }

    // MARK: Remove User

    private func presentRemoveUserMenuSheetController(from view: UIView) {
        let otherUser = viewModel.user

        let controller = UIAlertController(
            title: L10n.Localizable.Profile.removeDialogMessage(otherUser.name ?? ""),
            message: nil,
            preferredStyle: .actionSheet
        )

        let removeAction = UIAlertAction(title: L10n.Localizable.Profile.removeDialogButtonRemoveConfirm, style: .destructive) { _ in
            self.viewModel.conversation?.removeOrShowError(participant: otherUser) { result in
                switch result {
                case .success:
                    self.returnToPreviousScreen()
                case .failure:
                    break
                }
            }
        }

        controller.addAction(removeAction)
        controller.addAction(.cancel())

        presentAlert(controller, targetView: view)
    }

    private func duplicateUser() {
        guard DeveloperFlag.debugDuplicateObjects.isOn else { return }
        guard let user = viewModel.user as? ZMUser, let context = (self.viewModel.userSession as? ZMUserSession)?.syncContext else {
            assertionFailure("couldn't get context to duplicateUser")
            return
        }

        context.performAndWait {
            guard let original = ZMUser.existingObject(for: user.objectID, in: context) else {
                return
            }
            let duplicate = ZMUser.insertNewObject(in: context)
            duplicate.remoteIdentifier = original.remoteIdentifier
            duplicate.domain = original.domain
            duplicate.name = "duplicate user \(original.name ?? "<nil>")"
            duplicate.connection = original.connection
            duplicate.participantRoles = original.participantRoles
            duplicate.createdTeams = original.createdTeams
            context.saveOrRollback()

            WireLogger.conversation.debug("duplicate user \(String(describing: user.qualifiedID?.safeForLoggingDescription))")
        }
    }

    private func duplicateTeam() {
        guard let user = viewModel.user as? ZMUser,
              let context = (self.viewModel.userSession as? ZMUserSession)?.syncContext,
              let team = user.team else {
            assertionFailure("couldn't get context or has no team to duplicateTeam")
            WireLogger.conversation.debug("can't duplicate team")
            return
        }

        context.performAndWait {
            guard let original = Team.existingObject(for: team.objectID, in: context) else { return }
            let duplicate = Team.insertNewObject(in: context)
            duplicate.remoteIdentifier = original.remoteIdentifier
            duplicate.name = "duplicate team \(original.name ?? "<nil>")"
            duplicate.conversations = original.conversations
            duplicate.members = original.members
            duplicate.roles = original.roles
            duplicate.creator = original.creator

            context.saveOrRollback()

            WireLogger.conversation.debug("duplicate team \(original.remoteIdentifier?.safeForLoggingDescription ?? "<nil>")")
        }
    }

}

extension ProfileViewController: ProfileViewControllerDelegate {

    func profileViewController(_ controller: ProfileViewController?, wantsToNavigateTo conversation: ZMConversation) {
        delegate?.profileViewController(controller, wantsToNavigateTo: conversation)
    }

}

extension ProfileViewController: ConversationCreationControllerDelegate {

    func conversationCreationController(
        _ controller: ConversationCreationController,
        didCreateConversation conversation: ZMConversation
    ) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }

            delegate?.profileViewController(
                self,
                wantsToNavigateTo: conversation
            )
        }
    }

}

extension ProfileViewController: ProfileViewControllerViewModelDelegate {

    func setupNavigationItems() {
        let legalHoldItem: UIBarButtonItem? = viewModel.hasLegalHoldItem ? legalholdItem : nil

        if navigationController?.viewControllers.count == 1 {
            navigationItem.rightBarButtonItem = navigationController?.closeItem()
            navigationItem.leftBarButtonItem = legalHoldItem
        } else {
            navigationItem.rightBarButtonItem = legalHoldItem
        }
        navigationItem.rightBarButtonItem?.accessibilityLabel = L10n.Accessibility.Profile.CloseButton.description
        navigationItem.backBarButtonItem?.accessibilityLabel = L10n.Accessibility.DeviceDetails.BackButton.description
    }

    func updateFooterViews() {
        // Actions
        let factory = viewModel.profileActionsFactory
        let actions = factory.makeActionsList()

        profileFooterView.delegate = self
        profileFooterView.isHidden = actions.isEmpty
        incomingRequestFooterBottomConstraint?.priority = actions.isEmpty ? .required : .defaultLow
        profileFooterView.configure(with: actions)
        view.bringSubviewToFront(profileFooterView)

        // Incoming Request Footer
        incomingRequestFooter.isHidden = viewModel.incomingRequestFooterHidden
        incomingRequestFooter.delegate = self
        view.bringSubviewToFront(incomingRequestFooter)
    }

    func returnToPreviousScreen() {
        if let navigationController = self.navigationController, navigationController.viewControllers.first != self {
            navigationController.popViewController(animated: true)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    func presentError(_ error: LocalizedError) {
        typealias Strings = L10n.Localizable.Error.Connection

        if let connectionError = error as? ConnectToUserError,
           connectionError == .federationDenied {
            let message = Strings.federationDeniedMessage(viewModel.user.name ?? "")
            UIAlertController.showErrorAlert(title: "", message: message)
        } else {
            presentLocalizedErrorAlert(error)
        }
    }
}
