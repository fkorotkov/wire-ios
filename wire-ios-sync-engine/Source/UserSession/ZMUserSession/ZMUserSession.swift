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

import Combine
import Foundation
import WireDataModel
import WireRequestStrategy
import WireSystem

typealias UserSessionDelegate = UserSessionEncryptionAtRestDelegate
& UserSessionSelfUserClientDelegate
& UserSessionLogoutDelegate
& UserSessionAppLockDelegate

@objcMembers
public final class ZMUserSession: NSObject {

    // MARK: Properties

    private let appVersion: String
    private var tokens: [Any] = []
    private var tornDown: Bool = false

    private(set) var isNetworkOnline = true

    private(set) var coreDataStack: CoreDataStack!
    let application: ZMApplication
    let flowManager: FlowManagerType
    private(set) var mediaManager: MediaManagerType
    private(set) var analytics: AnalyticsType?
    private(set) var transportSession: TransportSessionType
    let storedDidSaveNotifications: ContextDidSaveNotificationPersistence
    let userExpirationObserver: UserExpirationObserver
    private(set) var updateEventProcessor: UpdateEventProcessor?
    private(set) var strategyDirectory: StrategyDirectoryProtocol?
    private(set) var syncStrategy: ZMSyncStrategy?
    private(set) var operationLoop: ZMOperationLoop?
    private(set) var notificationDispatcher: NotificationDispatcher
    private(set) var localNotificationDispatcher: LocalNotificationDispatcher?
    let applicationStatusDirectory: ApplicationStatusDirectory
    private(set) var callStateObserver: CallStateObserver?
    var messageReplyObserver: ManagedObjectContextChangeObserver?
    var likeMesssageObserver: ManagedObjectContextChangeObserver?
    private(set) var urlActionProcessors: [URLActionProcessor]?
    let debugCommands: [String: DebugCommand]
    let eventProcessingTracker: EventProcessingTracker = EventProcessingTracker()
    let legacyHotFix: ZMHotFix
    // When we move to the monorepo, uncomment hotFixApplicator
    // let hotFixApplicator = PatchApplicator<HotfixPatch>(lastRunVersionKey: "lastRunHotFixVersion")
    var accessTokenRenewalObserver: AccessTokenRenewalObserver?

    var recurringActionService: any RecurringActionServiceInterface

    var cryptoboxMigrationManager: CryptoboxMigrationManagerInterface
    private(set) var coreCryptoProvider: CoreCryptoProviderProtocol
    private(set) var userId: UUID
    private(set) lazy var proteusService: ProteusServiceInterface = ProteusService(coreCryptoProvider: coreCryptoProvider)
    private(set) var mlsService: MLSServiceInterface
    private(set) var proteusProvider: ProteusProviding!
    let proteusToMLSMigrationCoordinator: ProteusToMLSMigrationCoordinating
    let mlsConversationVerificationStatusUpdater: MLSConversationVerificationStatusUpdating
    let observeMLSGroupVerificationStatus: ObserveMLSGroupVerificationStatusUseCaseProtocol
    public let updateMLSGroupVerificationStatus: UpdateMLSGroupVerificationStatusUseCaseProtocol

    public lazy var featureRepository = FeatureRepository(context: syncContext)

    let earService: EARServiceInterface

    public internal(set) var appLockController: AppLockType
    private let contextStorage: LAContextStorable

    let useCaseFactory: UseCaseFactoryProtocol

    public let e2eiActivationDateRepository: E2EIActivationDateRepositoryProtocol

    let lastEventIDRepository: LastEventIDRepositoryInterface
    let conversationEventProcessor: ConversationEventProcessor

    public var hasCompletedInitialSync: Bool = false

    public var topConversationsDirectory: TopConversationsDirectory

    // MARK: Computed Properties

    var isPerformingSync = true {
        willSet {
            notificationDispatcher.operationMode = newValue ? .economical : .normal
        }
    }

    public var syncStatus: SyncStatusProtocol {
        return applicationStatusDirectory.syncStatus
    }

    public var fileSharingFeature: Feature.FileSharing {
        let featureRepository = FeatureRepository(context: coreDataStack.viewContext)
        return featureRepository.fetchFileSharing()
    }

    public var selfDeletingMessagesFeature: Feature.SelfDeletingMessages {
        let featureRepository = FeatureRepository(context: coreDataStack.viewContext)
        return featureRepository.fetchSelfDeletingMesssages()
    }

    public var conversationGuestLinksFeature: Feature.ConversationGuestLinks {
        let featureRepository = FeatureRepository(context: coreDataStack.viewContext)
        return featureRepository.fetchConversationGuestLinks()
    }

    public var classifiedDomainsFeature: Feature.ClassifiedDomains {
        let featureRepository = FeatureRepository(context: coreDataStack.viewContext)
        return featureRepository.fetchClassifiedDomains()
    }

    public var e2eiFeature: Feature.E2EI {
        let featureRepository = FeatureRepository(context: coreDataStack.viewContext)
        return featureRepository.fetchE2EI()
    }

    public var mlsFeature: Feature.MLS {
        let featureRepository = FeatureRepository(context: coreDataStack.viewContext)
        return featureRepository.fetchMLS()
    }

    public var gracePeriodEndDate: Date? {
        guard
            e2eiFeature.isEnabled,
            let e2eiActivatedAt = e2eiActivationDateRepository.e2eiActivatedAt
        else {
            return nil
        }

        let gracePeriod = TimeInterval(e2eiFeature.config.verificationExpiration)
        return e2eiActivatedAt.addingTimeInterval(gracePeriod)
    }

    public lazy var selfClientCertificateProvider: SelfClientCertificateProviderProtocol = {
        return SelfClientCertificateProvider(
            getE2eIdentityCertificatesUseCase: getE2eIdentityCertificates,
            context: syncContext)
    }()

    public lazy var snoozeCertificateEnrollmentUseCase: SnoozeCertificateEnrollmentUseCaseProtocol = {
        return SnoozeCertificateEnrollmentUseCase(
            featureRepository: featureRepository,
            featureRepositoryContext: syncContext,
            recurringActionService: recurringActionService,
            accountId: account.userIdentifier)
    }()

    public lazy var stopCertificateEnrollmentSnoozerUseCase: StopCertificateEnrollmentSnoozerUseCaseProtocol = {
        return StopCertificateEnrollmentSnoozerUseCase(
            recurringActionService: recurringActionService,
            accountId: account.userIdentifier)
    }()

    lazy var cRLsChecker: CertificateRevocationListsChecker = {
        return CertificateRevocationListsChecker(
            userID: userId,
            crlAPI: CertificateRevocationListAPI(),
            mlsConversationsVerificationUpdater: mlsConversationVerificationStatusUpdater,
            selfClientCertificateProvider: selfClientCertificateProvider,
            coreCryptoProvider: coreCryptoProvider,
            context: coreDataStack.syncContext
        )
    }()

    lazy var cRLsDistributionPointsObserver: CRLsDistributionPointsObserver = {
        return CRLsDistributionPointsObserver(
            cRLsChecker: self.cRLsChecker
        )
    }()

    public var managedObjectContext: NSManagedObjectContext { // TODO jacob we don't want this to be public
        return coreDataStack.viewContext
    }

    public var syncManagedObjectContext: NSManagedObjectContext { // TODO jacob we don't want this to be public
        return coreDataStack.syncContext
    }

    public var searchManagedObjectContext: NSManagedObjectContext { // TODO jacob we don't want this to be public
        return coreDataStack.searchContext
    }

    public var sharedContainerURL: URL { // TODO jacob we don't want this to be public
        return coreDataStack.applicationContainer
    }

    public var selfUserClient: UserClient? { // TODO jacob we don't want this to be public
        return ZMUser.selfUser(in: managedObjectContext).selfClient()
    }

    public var userProfile: UserProfile {
        return applicationStatusDirectory.userProfileUpdateStatus
    }

    public var userProfileImage: UserProfileImageUpdateProtocol {
        return applicationStatusDirectory.userProfileImageUpdateStatus
    }

    public var conversationDirectory: ConversationDirectoryType {
        return managedObjectContext.conversationListDirectory()
    }

    public private(set) var networkState: ZMNetworkState = .online {
        didSet {
            if oldValue != networkState {
                ZMNetworkAvailabilityChangeNotification.notify(networkState: networkState, userSession: self)
            }
        }
    }

    public var isNotificationContentHidden: Bool {
        get {
            guard let value = managedObjectContext.persistentStoreMetadata(forKey: LocalNotificationDispatcher.ZMShouldHideNotificationContentKey) as? NSNumber else {
                return false
            }

            return value.boolValue
        }
        set {
            managedObjectContext.setPersistentStoreMetadata(NSNumber(value: newValue), key: LocalNotificationDispatcher.ZMShouldHideNotificationContentKey)
        }
    }

    /// - Note: this is safe if coredataStack and proteus are ready
    public var getUserClientFingerprint: GetUserClientFingerprintUseCaseProtocol {
        GetUserClientFingerprintUseCase(
            syncContext: coreDataStack.syncContext,
            transportSession: transportSession,
            proteusProvider: proteusProvider
        )
    }

    lazy var e2eiRepository: E2EIRepositoryInterface = {
        let acmeDiscoveryPath = e2eiFeature.config.acmeDiscoveryUrl ?? ""
        let acmeApi = AcmeAPI(acmeDiscoveryPath: acmeDiscoveryPath)
        let httpClient = HttpClientImpl(
            transportSession: transportSession,
            queue: syncContext
        )

        let apiProvider = APIProvider(httpClient: httpClient)
        let e2eiSetupService = E2EISetupService(coreCryptoProvider: coreCryptoProvider, featureRepository: featureRepository)
        let onNewCRLsDistributionPointsSubject = PassthroughSubject<CRLsDistributionPoints, Never>()

        let keyRotator = E2EIKeyPackageRotator(
            coreCryptoProvider: coreCryptoProvider,
            conversationEventProcessor: conversationEventProcessor,
            context: syncContext,
            onNewCRLsDistributionPointsSubject: onNewCRLsDistributionPointsSubject
        )

        let e2eiRepository = E2EIRepository(
            acmeApi: acmeApi,
            apiProvider: apiProvider,
            e2eiSetupService: e2eiSetupService,
            keyRotator: keyRotator,
            coreCryptoProvider: coreCryptoProvider,
            onNewCRLsDistributionPointsSubject: onNewCRLsDistributionPointsSubject
        )

        cRLsDistributionPointsObserver.startObservingNewCRLsDistributionPoints(
            from: onNewCRLsDistributionPointsSubject.eraseToAnyPublisher()
        )

        return e2eiRepository
    }()

    public lazy var enrollE2EICertificate: EnrollE2EICertificateUseCaseProtocol = {
        return EnrollE2EICertificateUseCase(
            e2eiRepository: e2eiRepository,
            context: syncContext)
    }()

    private(set) public var lastE2EIUpdateDateRepository: LastE2EIdentityUpdateDateRepositoryInterface?

    public private(set) lazy var getIsE2eIdentityEnabled: GetIsE2EIdentityEnabledUseCaseProtocol = {
        return GetIsE2EIdentityEnabledUseCase(
            coreCryptoProvider: coreCryptoProvider,
            featureRespository: featureRepository
        )
    }()

    public private(set) lazy var getE2eIdentityCertificates: GetE2eIdentityCertificatesUseCaseProtocol = {
        return GetE2eIdentityCertificatesUseCase(
            coreCryptoProvider: coreCryptoProvider,
            syncContext: syncContext
        )
    }()

    @MainActor
    public private(set) lazy var isE2EICertificateEnrollmentRequired: IsE2EICertificateEnrollmentRequiredProtocol = {
        return IsE2EICertificateEnrollmentRequiredUseCase(
            isE2EIdentityEnabled: e2eiFeature.isEnabled,
            selfClientCertificateProvider: selfClientCertificateProvider,
            gracePeriodEndDate: gracePeriodEndDate)
    }()

    public lazy var changeUsername: ChangeUsernameUseCaseProtocol = {
        ChangeUsernameUseCase(userProfile: applicationStatusDirectory.userProfileUpdateStatus)
    }()

    // MARK: Dependency Injection

    let dependencies: UserSessionDependencies

    // MARK: Delegates

    weak var delegate: UserSessionDelegate?

    // swiftlint:disable:next todo_requires_jira_link
    // TODO: remove this property and move functionality to separate protocols under UserSessionDelegate
    public weak var sessionManager: SessionManagerType?

    // MARK: - Initialize

    init(
        userId: UUID,
        transportSession: any TransportSessionType,
        mediaManager: any MediaManagerType,
        flowManager: any FlowManagerType,
        analytics: (any AnalyticsType)?,
        application: ZMApplication,
        appVersion: String,
        coreDataStack: CoreDataStack,
        earService: any EARServiceInterface,
        mlsService: any MLSServiceInterface,
        cryptoboxMigrationManager: any CryptoboxMigrationManagerInterface,
        proteusToMLSMigrationCoordinator: any ProteusToMLSMigrationCoordinating,
        sharedUserDefaults: UserDefaults,
        useCaseFactory: any UseCaseFactoryProtocol,
        observeMLSGroupVerificationStatusUseCase: any ObserveMLSGroupVerificationStatusUseCaseProtocol,
        appLock: any AppLockType,
        coreCryptoProvider: any CoreCryptoProviderProtocol,
        lastEventIDRepository: any LastEventIDRepositoryInterface,
        lastE2EIUpdateDateRepository: any LastE2EIdentityUpdateDateRepositoryInterface,
        e2eiActivationDateRepository: any E2EIActivationDateRepositoryProtocol,
        applicationStatusDirectory: ApplicationStatusDirectory,
        updateMLSGroupVerificationStatusUseCase: any UpdateMLSGroupVerificationStatusUseCaseProtocol,
        mlsConversationVerificationStatusUpdater: any MLSConversationVerificationStatusUpdating,
        contextStorage: LAContextStorable,
        recurringActionService: any RecurringActionServiceInterface,
        dependencies: UserSessionDependencies
    ) {
        self.application = application
        self.appVersion = appVersion
        self.flowManager = flowManager
        self.mediaManager = mediaManager
        self.analytics = analytics
        self.coreDataStack = coreDataStack
        self.transportSession = transportSession
        self.notificationDispatcher = NotificationDispatcher(managedObjectContext: coreDataStack.viewContext)
        self.storedDidSaveNotifications = ContextDidSaveNotificationPersistence(accountContainer: coreDataStack.accountContainer)
        self.userExpirationObserver = UserExpirationObserver(managedObjectContext: coreDataStack.viewContext)
        self.topConversationsDirectory = TopConversationsDirectory(managedObjectContext: coreDataStack.viewContext)
        self.debugCommands = ZMUserSession.initDebugCommands()
        self.legacyHotFix = ZMHotFix(syncMOC: coreDataStack.syncContext)
        self.appLockController = appLock
        self.coreCryptoProvider = coreCryptoProvider
        self.lastEventIDRepository = lastEventIDRepository
        self.userId = userId
        self.lastE2EIUpdateDateRepository = lastE2EIUpdateDateRepository
        self.e2eiActivationDateRepository = e2eiActivationDateRepository
        self.applicationStatusDirectory = applicationStatusDirectory
        self.earService = earService
        self.mlsService = mlsService
        self.cryptoboxMigrationManager = cryptoboxMigrationManager
        self.conversationEventProcessor = ConversationEventProcessor(context: coreDataStack.syncContext)
        self.proteusToMLSMigrationCoordinator = proteusToMLSMigrationCoordinator
        self.useCaseFactory = useCaseFactory
        self.updateMLSGroupVerificationStatus = updateMLSGroupVerificationStatusUseCase
        self.mlsConversationVerificationStatusUpdater = mlsConversationVerificationStatusUpdater
        self.observeMLSGroupVerificationStatus = observeMLSGroupVerificationStatusUseCase
        self.contextStorage = contextStorage
        self.recurringActionService = recurringActionService
        self.dependencies = dependencies
    }

    func setup(
        eventProcessor: (any UpdateEventProcessor)?,
        strategyDirectory: (any StrategyDirectoryProtocol)?,
        syncStrategy: ZMSyncStrategy?,
        operationLoop: ZMOperationLoop?,
        configuration: Configuration
    ) {
        coreDataStack.linkAnalytics(analytics)
        coreDataStack.linkCaches(dependencies.caches)
        coreDataStack.linkContexts()

        // As we move the flag value from CoreData to UserDefaults, we set an initial value
        self.earService.setInitialEARFlagValue(viewContext.encryptMessagesAtRest)
        self.earService.delegate = self
        appLockController.delegate = self
        applicationStatusDirectory.syncStatus.syncStateDelegate = self
        applicationStatusDirectory.clientRegistrationStatus.registrationStatusDelegate = self

        syncManagedObjectContext.performGroupedBlockAndWait { [self] in
            self.localNotificationDispatcher = LocalNotificationDispatcher(in: coreDataStack.syncContext)
            self.configureTransportSession()

            // need to be before we create strategies since it is passed
            self.proteusProvider = ProteusProvider(proteusService: self.proteusService,
                                                   keyStore: self.syncManagedObjectContext.zm_cryptKeyStore)

            self.strategyDirectory = strategyDirectory ?? self.createStrategyDirectory(useLegacyPushNotifications: configuration.useLegacyPushNotifications)
            self.updateEventProcessor = eventProcessor ?? self.createUpdateEventProcessor()
            self.syncStrategy = syncStrategy ?? self.createSyncStrategy()
            self.operationLoop = operationLoop ?? self.createOperationLoop()
            self.urlActionProcessors = self.createURLActionProcessors()
            self.callStateObserver = CallStateObserver(localNotificationDispatcher: self.localNotificationDispatcher!,
                                                       contextProvider: self,
                                                       callNotificationStyleProvider: self)

            // FIXME: [WPB-5827] inject instead of storing on context - [jacob]
            self.syncManagedObjectContext.proteusService = self.proteusService
            self.syncManagedObjectContext.mlsService = self.mlsService

            applicationStatusDirectory.clientRegistrationStatus.prepareForClientRegistration()
            self.applicationStatusDirectory.syncStatus.determineInitialSyncPhase()
            self.applicationStatusDirectory.clientUpdateStatus.determineInitialClientStatus()
            self.applicationStatusDirectory.clientRegistrationStatus.determineInitialRegistrationStatus()
            self.hasCompletedInitialSync = self.applicationStatusDirectory.syncStatus.isSlowSyncing == false

            self.observeMLSGroupVerificationStatus.invoke()
            self.cRLsDistributionPointsObserver.startObservingNewCRLsDistributionPoints(
                from: self.mlsService.onNewCRLsDistributionPoints()
            )
        }

        registerForCalculateBadgeCountNotification()
        registerForRegisteringPushTokenNotification()
        registerForBackgroundNotifications()
        enableBackgroundFetch()
        observeChangesOnShareExtension()
        startEphemeralTimers()
        notifyUserAboutChangesInAvailabilityBehaviourIfNeeded()
        RequestAvailableNotification.notifyNewRequestsAvailable(self)
        restoreDebugCommandsState()
        configureRecurringActions()
    }

    // MARK: - Deinitalize

    deinit {
        require(tornDown, "tearDown must be called before the ZMUserSession is deallocated")
    }

    public func tearDown() {
        guard !tornDown else { return }

        tokens.removeAll()
        application.unregisterObserverForStateChange(self)
        callStateObserver = nil
        syncStrategy?.tearDown()
        syncStrategy = nil
        operationLoop?.tearDown()
        operationLoop = nil
        transportSession.tearDown()
        notificationDispatcher.tearDown()
        callCenter?.tearDown()
        coreDataStack.close()
        contextStorage.clear()

        NotificationCenter.default.removeObserver(self)

        tornDown = true
    }

    // MARK: - Methods

    private func configureTransportSession() {
        transportSession.pushChannel.clientID = selfUserClient?.remoteIdentifier
        transportSession.setNetworkStateDelegate(self)
        transportSession.setAccessTokenRenewalFailureHandler { [weak self] response in
            self?.transportSessionAccessTokenDidFail(response: response)
        }
        transportSession.setAccessTokenRenewalSuccessHandler { [weak self]  _, _ in
            self?.transportSessionAccessTokenDidSucceed()
        }
    }

    private func createStrategyDirectory(useLegacyPushNotifications: Bool) -> StrategyDirectoryProtocol {
        return StrategyDirectory(
            contextProvider: coreDataStack,
            applicationStatusDirectory: applicationStatusDirectory,
            cookieStorage: transportSession.cookieStorage,
            pushMessageHandler: localNotificationDispatcher!,
            flowManager: flowManager,
            updateEventProcessor: self,
            localNotificationDispatcher: localNotificationDispatcher!,
            useLegacyPushNotifications: useLegacyPushNotifications,
            lastEventIDRepository: lastEventIDRepository,
            transportSession: transportSession,
            proteusProvider: self.proteusProvider,
            mlsService: mlsService,
            coreCryptoProvider: coreCryptoProvider,
            usecaseFactory: useCaseFactory,
            searchUsersCache: dependencies.caches.searchUsers
        )
    }

    private func createUpdateEventProcessor() -> EventProcessor {
        EventProcessor(
            storeProvider: coreDataStack,
            eventProcessingTracker: eventProcessingTracker,
            earService: earService,
            eventConsumers: strategyDirectory?.eventConsumers ?? [],
            eventAsyncConsumers: (strategyDirectory?.eventAsyncConsumers ?? []) + [conversationEventProcessor]
        )
    }

    private func createURLActionProcessors() -> [URLActionProcessor] {
        return [
            DeepLinkURLActionProcessor(
                contextProvider: coreDataStack,
                transportSession: transportSession,
                eventProcessor: updateEventProcessor!
            ),
            ConnectToBotURLActionProcessor(
                contextprovider: coreDataStack,
                transportSession: transportSession,
                eventProcessor: updateEventProcessor!,
                searchUsersCache: dependencies.caches.searchUsers
            )
        ]
    }

    private func createSyncStrategy() -> ZMSyncStrategy {
        return ZMSyncStrategy(contextProvider: coreDataStack,
                              notificationsDispatcher: notificationDispatcher,
                              operationStatus: applicationStatusDirectory.operationStatus,
                              application: application,
                              strategyDirectory: strategyDirectory!,
                              eventProcessingTracker: eventProcessingTracker)
    }

    private func createOperationLoop() -> ZMOperationLoop {
        return ZMOperationLoop(transportSession: transportSession,
                               requestStrategy: syncStrategy,
                               updateEventProcessor: updateEventProcessor!,
                               operationStatus: applicationStatusDirectory.operationStatus,
                               syncStatus: applicationStatusDirectory.syncStatus,
                               pushNotificationStatus: applicationStatusDirectory.pushNotificationStatus,
                               callEventStatus: applicationStatusDirectory.callEventStatus,
                               uiMOC: managedObjectContext,
                               syncMOC: syncManagedObjectContext)
    }

    private func configureRecurringActions() {
        recurringActionService.registerAction(refreshUsersMissingMetadataAction)
        recurringActionService.registerAction(refreshConversationsMissingMetadataAction)
        recurringActionService.registerAction(updateProteusToMLSMigrationStatusAction)
        recurringActionService.registerAction(refreshTeamMetadataAction)
        recurringActionService.registerAction(refreshFederationCertificatesAction)
    }

    func startRequestLoopTracker() {
        transportSession.requestLoopDetectionCallback = { path in
            guard !path.hasSuffix("/typing") else { return }

            Logging.network.warn("Request loop happening at path: \(path)")

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .loggingRequestLoop,
                                                object: nil,
                                                userInfo: ["path": path])
            }
        }
    }

    private func registerForCalculateBadgeCountNotification() {
        tokens.append(NotificationInContext.addObserver(name: .calculateBadgeCount, context: managedObjectContext.notificationContext) { [weak self] _ in
            self?.calculateBadgeCount()
        })
    }

    /// Count number of conversations with unread messages and update the application icon badge count.
    private func calculateBadgeCount() {
        let accountID = coreDataStack.account.userIdentifier
        let unreadCount = Int(ZMConversation.unreadConversationCount(in: self.syncManagedObjectContext))
        Logging.push.safePublic("Updating badge count for \(accountID) to \(SanitizedString(stringLiteral: String(unreadCount)))")
        self.sessionManager?.updateAppIconBadge(accountID: accountID, unreadCount: unreadCount)
    }

    private func registerForBackgroundNotifications() {
        application.registerObserverForDidEnterBackground(self, selector: #selector(applicationDidEnterBackground(_:)))
        application.registerObserverForWillEnterForeground(self, selector: #selector(applicationWillEnterForeground(_:)))

    }

    private func enableBackgroundFetch() {
        // We enable background fetch by setting the minimum interval to something different from UIApplicationBackgroundFetchIntervalNever
        application.setMinimumBackgroundFetchInterval(10.0 * 60.0 + Double.random(in: 0..<300))
    }

    private func notifyUserAboutChangesInAvailabilityBehaviourIfNeeded() {
        syncManagedObjectContext.performGroupedBlock {
            self.localNotificationDispatcher?.notifyAvailabilityBehaviourChangedIfNeeded()
        }
    }

    // MARK: Progress Events

    // temporary function to simplify call to EventProcessor
    // might be replaced by something more elegant
    public func processUpdateEvents(_ events: [ZMUpdateEvent]) {
        WaitingGroupTask(context: self.syncContext) {
            try? await self.updateEventProcessor?.processEvents(events)
        }
    }

    // temporary function to simplify call to ConversationEventProcessor
    // might be replaced by something more elegant
    public func processConversationEvents(_ events: [ZMUpdateEvent]) {
        WaitingGroupTask(context: self.syncContext) {
            await self.conversationEventProcessor.processConversationEvents(events)
        }
    }

    // MARK: Network

    public func requestResyncResources() {
        applicationStatusDirectory.requestResyncResources()
    }

    // MARK: Access Token

    private func renewAccessTokenIfNeeded(for userClient: UserClient) {
        guard
            let apiVersion = BackendInfo.apiVersion,
            apiVersion > .v2,
            let clientID = userClient.remoteIdentifier
        else { return }

        renewAccessToken(with: clientID)
    }

    // MARK: Perform changes

    public func saveOrRollbackChanges() {
        managedObjectContext.saveOrRollback()
    }

    @objc(performChanges:)
    public func perform(_ changes: @escaping () -> Void) {
        managedObjectContext.performGroupedBlockAndWait { [weak self] in
            changes()
            self?.saveOrRollbackChanges()
        }
    }

    @objc(enqueueChanges:)
    public func enqueue(_ changes: @escaping () -> Void) {
        enqueue(changes, completionHandler: nil)
    }

    @objc(enqueueChanges:completionHandler:)
    public func enqueue(_ changes: @escaping () -> Void, completionHandler: (() -> Void)?) {
        managedObjectContext.performGroupedBlock { [weak self] in
            changes()
            self?.saveOrRollbackChanges()
            completionHandler?()
        }
    }

    @objc(enqueueDelayedChanges:completionHandler:)
    public func enqueueDelayed(_ changes: @escaping () -> Void, completionHandler: (() -> Void)?) {
        managedObjectContext.performGroupedBlock { [weak self] in
            changes()
            self?.saveOrRollbackChanges()

            let group = ZMSDispatchGroup(label: "enqueueDelayedChanges")
            self?.managedObjectContext.enqueueDelayedSave(with: group)

            group.notify(on: DispatchQueue.global(qos: .background), block: {
                self?.managedObjectContext.performGroupedBlock {
                    completionHandler?()
                }
            })
        }
    }

    // MARK: Account

    public func initiateUserDeletion() {
        syncManagedObjectContext.performGroupedBlock {
            self.syncManagedObjectContext.setPersistentStoreMetadata(NSNumber(value: true), key: DeleteAccountRequestStrategy.userDeletionInitiatedKey)
            RequestAvailableNotification.notifyNewRequestsAvailable(self)
        }
    }

    // MARK: Caches

    func purgeTemporaryAssets() throws {
        try dependencies.caches.fileAssets.purgeTemporaryAssets()
    }

}

// MARK: - ZMNetworkStateDelegate

extension ZMUserSession: ZMNetworkStateDelegate {

    public func didReceiveData() {
        managedObjectContext.performGroupedBlock { [weak self] in
            self?.isNetworkOnline = true
            self?.updateNetworkState()
        }
    }

    public func didGoOffline() {
        managedObjectContext.performGroupedBlock { [weak self] in
            self?.isNetworkOnline = false
            self?.updateNetworkState()
            self?.saveOrRollbackChanges()

        }
    }

    func updateNetworkState() {
        let state: ZMNetworkState

        if isNetworkOnline {
            if isPerformingSync {
                state = .onlineSynchronizing
            } else {
                state = .online
            }
        } else {
            state = .offline
        }

        networkState = state
    }
}

// MARK: - UpdateEventProcessor

// swiftlint:disable todo_requires_jira_link
// TODO: [jacob] find another way of providing the event processor to ZMissingEventTranscoder
// swiftlint:enable todo_requires_jira_link
extension ZMUserSession: UpdateEventProcessor {
    public func bufferEvents(_ events: [WireTransport.ZMUpdateEvent]) async {
        await updateEventProcessor?.bufferEvents(events)
    }

    public func processEvents(_ events: [WireTransport.ZMUpdateEvent]) async throws {
        try await updateEventProcessor?.processEvents(events)
    }

    public func processBufferedEvents() async throws {
        try await updateEventProcessor?.processBufferedEvents()
    }
}

// MARK: - ZMSyncStateDelegate

extension ZMUserSession: ZMSyncStateDelegate {

    public func didStartSlowSync() {
        managedObjectContext.performGroupedBlock { [weak self] in
            self?.isPerformingSync = true
            self?.notificationDispatcher.isEnabled = false
            self?.updateNetworkState()
        }
    }

    public func didFinishSlowSync() {
        managedObjectContext.performGroupedBlock { [weak self] in
            guard let self else { return }

            self.hasCompletedInitialSync = true
            self.notificationDispatcher.isEnabled = true
            delegate?.clientCompletedInitialSync(accountId: account.userIdentifier)
            ZMUserSession.notifyInitialSyncCompleted(context: managedObjectContext)
        }

        let selfClient = ZMUser.selfUser(in: syncContext).selfClient()

        if selfClient?.hasRegisteredMLSClient == true {
            Task {
                await mlsService.repairOutOfSyncConversations()
            }
        }
    }

    public func didStartQuickSync() {
        WireLogger.sync.debug("did start quick sync")
        managedObjectContext.performGroupedBlock { [weak self] in
            self?.isPerformingSync = true
            self?.updateNetworkState()
        }
    }

    public func didFinishQuickSync() {
        WireLogger.sync.debug("did finish quick sync")
        processEvents()

        NotificationInContext(
            name: .quickSyncCompletedNotification,
            context: syncContext.notificationContext
        ).post()

        let selfClient = ZMUser.selfUser(in: syncContext).selfClient()
        if selfClient?.hasRegisteredMLSClient == true {

            WaitingGroupTask(context: syncContext) { [self] in
                // these operations are not dependent and should not be executed in same do/catch
                do {
                    // rework implementation of following method - WPB-6053
                    try await mlsService.performPendingJoins()
                } catch {
                    WireLogger.mls.error("Failed to performPendingJoins: \(String(reflecting: error))")
                }
                await mlsService.uploadKeyPackagesIfNeeded()
                await mlsService.updateKeyMaterialForAllStaleGroupsIfNeeded()
            }
        }

        mlsService.commitPendingProposalsIfNeeded()

        WaitingGroupTask(context: syncContext) { [self] in
            do {
                var getFeatureConfigAction = GetFeatureConfigsAction()
                try await getFeatureConfigAction.perform(in: syncContext.notificationContext)
                try await useCaseFactory.createResolveOneOnOneUseCase().invoke()
            } catch {
                WireLogger.mls.error("Failed to resolve one on one conversations: \(String(reflecting: error))")
            }
        }

        recurringActionService.performActionsIfNeeded()

        Task {
            await self.cRLsChecker.checkExpiredCRLs()
        }
    }

    func processEvents() {
        managedObjectContext.performGroupedBlock { [weak self] in
            self?.isPerformingSync = true
            self?.updateNetworkState()
        }

        let groups = self.syncContext.enterAllGroupsExceptSecondary()
        Task {
            var processingInterrupted = false
            do {
                try await updateEventProcessor?.processBufferedEvents()
            } catch {
                processingInterrupted = true
            }

            let isSyncing = await syncContext.perform { self.applicationStatusDirectory.syncStatus.isSyncing }

            if !processingInterrupted {
                await syncContext.perform {
                    self.legacyHotFix.applyPatches()
                    // When we move to the monorepo, uncomment hotFixApplicator applyPatches
                    // hotFixApplicator.applyPatches(HotfixPatch.self, in: syncContext)
                }
            }

            await managedObjectContext.perform { [weak self] in
                self?.isPerformingSync = isSyncing || processingInterrupted
                self?.updateNetworkState()
            }
            self.syncContext.leaveAllGroups(groups)
        }
    }

    func processPendingCallEvents(completionHandler: @escaping () -> Void) {
        WireLogger.updateEvent.info("process pending call events")
        Task {
            do {
                try await updateEventProcessor!.processBufferedEvents()
                await managedObjectContext.perform {
                    completionHandler()
                }
            } catch {
                WireLogger.mls.error("Failed to process pending call events: \(String(reflecting: error))")
            }
        }
    }

    public func didRegisterSelfUserClient(_ userClient: UserClient) {
        // If during registration user allowed notifications,
        // The push token can only be registered after client registration
        transportSession.pushChannel.clientID = userClient.remoteIdentifier
        registerCurrentPushToken()
        renewAccessTokenIfNeeded(for: userClient)

        UserClient.triggerSelfClientCapabilityUpdate(syncContext)

        managedObjectContext.performGroupedBlock { [weak self] in
            guard
                let context = self?.managedObjectContext,
                let accountId = ZMUser.selfUser(in: context).remoteIdentifier
            else {
                return
            }

            self?.delegate?.clientRegistrationDidSucceed(accountId: accountId)
        }
    }

    public func didFailToRegisterSelfUserClient(error: Error) {
        managedObjectContext.performGroupedBlock {  [weak self] in
            guard
                let context = self?.managedObjectContext,
                let accountId = ZMUser.selfUser(in: context).remoteIdentifier
            else {
                return
            }

            self?.delegate?.clientRegistrationDidFail(error as NSError, accountId: accountId)
        }
    }

    public func didDeleteSelfUserClient(error: Error) {
        notifyAuthenticationInvalidated(error)
    }

    func notifyAuthenticationInvalidated(_ error: Error) {
        WireLogger.authentication.debug("notifying authentication invalidated")
        managedObjectContext.performGroupedBlock {  [weak self] in
            guard
                let context = self?.managedObjectContext,
                let accountId = ZMUser.selfUser(in: context).remoteIdentifier
            else {
                return
            }

            self?.delegate?.authenticationInvalidated(error as NSError, accountId: accountId)
        }
    }

    func checkE2EICertificateExpiryStatus() {
        guard e2eiFeature.isEnabled else { return }

        NotificationCenter.default.post(name: E2EI.checkForE2EICertificateExpiryStatus, object: nil)
    }
}

// MARK: - URLActionProcessor

extension ZMUserSession: URLActionProcessor {
    func process(urlAction: URLAction, delegate: PresentationDelegate?) {
        urlActionProcessors?.forEach({ $0.process(urlAction: urlAction, delegate: delegate) })
    }
}

// MARK: - ContextProvider

extension ZMUserSession: ContextProvider {

    public var account: Account {
        return coreDataStack.account
    }

    public var viewContext: NSManagedObjectContext {
        return coreDataStack.viewContext
    }

    public var syncContext: NSManagedObjectContext {
        return coreDataStack.syncContext
    }

    public var searchContext: NSManagedObjectContext {
        return coreDataStack.searchContext
    }

    public var eventContext: NSManagedObjectContext {
        return coreDataStack.eventContext
    }
}

// MARK: - NotificationName + LoggingRequestLoopNotificationName

extension Notification.Name {
    public static let loggingRequestLoop = Self("LoggingRequestLoopNotificationName")
}
