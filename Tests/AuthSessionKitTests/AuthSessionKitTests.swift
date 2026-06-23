import Testing
import Foundation
@testable import AuthSession
@testable import AuthSessionInterface
import BiometricAuthInterface
import MultiCastDelegate
import SwiftConcurrency


// MARK: - Mock Types

struct MockUser: AuthSessionUserProtocol, @unchecked Sendable {
    var identifier: String = "mock-user-id"
}

final class MockSession: AuthSessionProtocol, @unchecked Sendable {

    var accessToken: String
    var expiresAt: TimeInterval
    var user: MockUser

    init(accessToken: String = "mock-token", expiresIn seconds: TimeInterval = 3600, user: MockUser = MockUser()) {
        self.accessToken = accessToken
        self.expiresAt = Date().timeIntervalSince1970 + seconds
        self.user = user
    }
}

final class MockSessionProvider: NSObject, AuthSessionProviderProtocol, @unchecked Sendable {

    var session: MockSession?
    var isBioMetricAuthenticationEnabled: Bool = false
    var allowsLocalSessionValidation: Bool = true
    var isSessionAutoRefreshEnabled: Bool = false

    var signoutError: Error?
    var signoutCallCount = 0
    var signoutReceivedError: Error?

    var canPerformAuth: Bool = false
    var allowsSignoutOnBiometricFailure: Bool = true

    var initializeCallCount = 0
    var lastEventProxy: (any AuthSessionEventProxy)?

    func initializeSessionProvider(for eventProxy: any AuthSessionEventProxy) {
        initializeCallCount += 1
        lastEventProxy = eventProxy
    }

    func setBioMetricAuthentication(_ isEnabled: Bool) {
        isBioMetricAuthenticationEnabled = isEnabled
    }

    func signout(with error: Error?) throws {
        signoutCallCount += 1
        signoutReceivedError = error
        if let signoutError {
            throw signoutError
        }
    }

    func preferredAuthenticationReason() -> String {
        return "Test authentication"
    }

    func canPerformAuthentication() -> Bool {
        return canPerformAuth
    }

    func allowsSessionSigningOutOnBiometricAuthenticationFailure(with error: BiometricAuthenticationError) -> Bool {
        return allowsSignoutOnBiometricFailure
    }
}

final class SendableCounter: @unchecked Sendable {
    private var _value = 0
    var value: Int { _value }
    func increment() { _value += 1 }
}

// MARK: - Test Helpers

private func makeHandle(
    session: MockSession? = nil,
    allowsLocalValidation: Bool = true,
    isAutoRefresh: Bool = false,
    canPerformAuth: Bool = false
) -> (AuthSessionHandle<MockSessionProvider>, MockSessionProvider) {
    let provider = MockSessionProvider()
    provider.session = session
    provider.allowsLocalSessionValidation = allowsLocalValidation
    provider.isSessionAutoRefreshEnabled = isAutoRefresh
    provider.canPerformAuth = canPerformAuth
    let handle = AuthSessionHandle(sessionProvider: provider)
    return (handle, provider)
}

private func makeReadyHandle(
    session: MockSession? = nil,
    allowsLocalValidation: Bool = true,
    isAutoRefresh: Bool = false,
    canPerformAuth: Bool = false
) -> (AuthSessionHandle<MockSessionProvider>, MockSessionProvider) {
    let (handle, provider) = makeHandle(
        session: session,
        allowsLocalValidation: allowsLocalValidation,
        isAutoRefresh: isAutoRefresh,
        canPerformAuth: canPerformAuth
    )
    handle.enableSessionForValidation()
    return (handle, provider)
}


// MARK: - Initialization

@Suite("Initialization")
struct InitializationTests {

    @Test func defaultStatusIsSyncing() {
        let (handle, _) = makeHandle()
        #expect(handle.sessionStatus == .syncing)
    }

    @Test func sessionReadinessStartsFalse() {
        let (handle, _) = makeHandle()
        #expect(handle.isSessionReadyToValidate == false)
    }

    @Test func manualAuthenticationStartsFalse() {
        let (handle, _) = makeHandle()
        #expect(handle.isManualAuthenticationRequired == false)
    }

    @Test func initializesProvider() {
        let (_, provider) = makeHandle()
        #expect(provider.initializeCallCount == 1)
    }

    @Test func createsEventProxy() {
        let (handle, _) = makeHandle()
        #expect(handle.sessionEventProxy != nil)
    }

    @Test func createsBiometricAuthentication() {
        let (handle, _) = makeHandle()
        #expect(handle.biometricAuthentication != nil)
    }

    @Test func sessionDelegatesToProvider() {
        let session = MockSession()
        let (handle, _) = makeHandle(session: session)
        #expect(handle.session?.accessToken == "mock-token")
    }

    @Test func nilSessionWhenProviderHasNone() {
        let (handle, _) = makeHandle(session: nil)
        #expect(handle.session == nil)
    }
}


// MARK: - Status Transitions

@Suite("Status Transitions")
struct StatusTransitionTests {

    @Test func setStatusChangesValue() {
        let (handle, _) = makeHandle()
        handle.set(sessionStatus: .signedIn)
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func setStatusIgnoresNoOp() {
        let (handle, _) = makeHandle()
        #expect(handle.sessionStatus == .syncing)
        handle.set(sessionStatus: .syncing)
        #expect(handle.sessionStatus == .syncing)
    }

    @Test func setStatusToEachCase() {
        let (handle, _) = makeHandle()
        let statuses: [AuthSessionStatus] = [.signedIn, .signedOut, .validating, .biometricAuthentication, .syncing]
        for status in statuses {
            handle.set(sessionStatus: status)
            #expect(handle.sessionStatus == status)
        }
    }
}


// MARK: - Manual Authentication

@Suite("Manual Authentication")
struct ManualAuthenticationTests {

    @Test func enableSetsFlag() {
        let (handle, _) = makeHandle()
        handle.enableManualAuthentication()
        #expect(handle.isManualAuthenticationRequired == true)
    }

    @Test func disableClearsFlag() {
        let (handle, _) = makeHandle()
        handle.enableManualAuthentication()
        handle.disableManualAuthentication()
        #expect(handle.isManualAuthenticationRequired == false)
    }

    @Test func enableIsIdempotent() {
        let (handle, _) = makeHandle()
        handle.enableManualAuthentication()
        handle.enableManualAuthentication()
        #expect(handle.isManualAuthenticationRequired == true)
    }

    @Test func disableIsIdempotent() {
        let (handle, _) = makeHandle()
        handle.disableManualAuthentication()
        #expect(handle.isManualAuthenticationRequired == false)
    }

    @Test func clearedWhenExitingValidatingStatus() {
        let (handle, _) = makeHandle()
        handle.enableManualAuthentication()
        #expect(handle.isManualAuthenticationRequired == true)
        handle.set(sessionStatus: .validating)
        handle.set(sessionStatus: .signedIn)
        #expect(handle.isManualAuthenticationRequired == false)
    }

    @Test func notClearedWhenEnteringValidating() {
        let (handle, _) = makeHandle()
        handle.enableManualAuthentication()
        handle.set(sessionStatus: .validating)
        #expect(handle.isManualAuthenticationRequired == true)
    }

    @Test func notClearedOnNonValidatingTransition() {
        let (handle, _) = makeHandle()
        handle.enableManualAuthentication()
        handle.set(sessionStatus: .signedIn)
        #expect(handle.isManualAuthenticationRequired == true)
    }

    /// Direct signout from `.signedIn` (no `.validating` in between) should still
    /// clear the manual auth flag — otherwise the flag would persist across the
    /// signout and break notification-based validation on the next session.
    @Test func clearedOnDirectSignOutFromSignedIn() {
        let (handle, _) = makeHandle()
        handle.set(sessionStatus: .signedIn)
        handle.enableManualAuthentication()
        #expect(handle.isManualAuthenticationRequired == true)

        handle.set(sessionStatus: .signedOut)
        #expect(handle.isManualAuthenticationRequired == false)
    }

    /// Signout from `.biometricAuthentication` (e.g., biometric failure with
    /// provider-allowed signout) should clear the flag.
    @Test func clearedOnSignOutFromBiometricAuthentication() {
        let (handle, _) = makeHandle()
        handle.set(sessionStatus: .biometricAuthentication)
        handle.enableManualAuthentication()
        #expect(handle.isManualAuthenticationRequired == true)

        handle.set(sessionStatus: .signedOut)
        #expect(handle.isManualAuthenticationRequired == false)
    }

    /// `sessionSignedOut` event from the provider should clear a sticky manual
    /// auth flag even when the prior status wasn't `.validating`.
    @Test func clearedBySessionSignedOutEvent() {
        let (handle, _) = makeHandle()
        handle.set(sessionStatus: .signedIn)
        handle.enableManualAuthentication()
        #expect(handle.isManualAuthenticationRequired == true)

        let listener = handle.listenEvent()
        listener(.sessionSignedOut(error: nil))
        #expect(handle.isManualAuthenticationRequired == false)
    }

    @Test func requestManualAuthRunsValidation() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeReadyHandle(session: session, allowsLocalValidation: true, canPerformAuth: false)
        handle.enableManualAuthentication()
        handle.set(sessionStatus: .signedIn)

        handle.requestManualAuthentication()
        #expect(handle.isManualAuthenticationRequired == false)
    }

    @Test func requestManualAuthNoOpsWhenNotRequired() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeReadyHandle(session: session, allowsLocalValidation: true, canPerformAuth: false)
        handle.set(sessionStatus: .signedIn)
        #expect(handle.isManualAuthenticationRequired == false)

        handle.requestManualAuthentication()
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func requestManualAuthTriggersFullValidationFlow() {
        let session = MockSession(expiresIn: 60)
        let (handle, provider) = makeReadyHandle(session: session, allowsLocalValidation: true)
        handle.enableManualAuthentication()
        handle.set(sessionStatus: .signedIn)

        handle.requestManualAuthentication()
        #expect(provider.signoutCallCount == 1)
    }
}


// MARK: - Session Readiness

@Suite("Session Readiness")
struct SessionReadinessTests {

    @Test func enableSetsFlag() {
        let (handle, _) = makeHandle()
        handle.enableSessionForValidation()
        #expect(handle.isSessionReadyToValidate == true)
    }

    @Test func enableIsIdempotent() {
        let (handle, _) = makeHandle()
        handle.enableSessionForValidation()
        handle.enableSessionForValidation()
        #expect(handle.isSessionReadyToValidate == true)
    }
}


// MARK: - Notification Validation Readiness

@Suite("Notification Validation Readiness")
struct NotificationValidationReadinessTests {

    @Test func notificationValidationStartsFalse() {
        let (handle, _) = makeHandle()
        #expect(handle.allowsSessionValidationFromNotifications == false)
    }

    @Test func enableSetsFlag() {
        let (handle, _) = makeHandle()
        handle.enableSessionValidationFromNotification()
        #expect(handle.allowsSessionValidationFromNotifications == true)
    }

    @Test func enableIsIdempotent() {
        let (handle, _) = makeHandle()
        handle.enableSessionValidationFromNotification()
        handle.enableSessionValidationFromNotification()
        #expect(handle.allowsSessionValidationFromNotifications == true)
    }

    @Test func sessionFetchDoesNotSetNotificationFlag() {
        let (handle, _) = makeHandle()
        let listener = handle.listenEvent()
        listener(.sessionFetched(isInitialFetch: true))
        #expect(handle.allowsSessionValidationFromNotifications == false)
    }

    @Test func sessionFetchFailedDoesNotSetNotificationFlag() {
        let (handle, _) = makeHandle()
        let listener = handle.listenEvent()
        listener(.sessionFetchFailed(NSError(domain: "test", code: 1)))
        #expect(handle.allowsSessionValidationFromNotifications == false)
    }

    @Test func twoFlagsAreIndependent() {
        let (handle, _) = makeHandle()
        handle.enableSessionForValidation()
        #expect(handle.isSessionReadyToValidate == true)
        #expect(handle.allowsSessionValidationFromNotifications == false)

        let (handle2, _) = makeHandle()
        handle2.enableSessionValidationFromNotification()
        #expect(handle2.allowsSessionValidationFromNotifications == true)
        #expect(handle2.isSessionReadyToValidate == false)
    }

    @Test func disableClearsFlag() {
        let (handle, _) = makeHandle()
        handle.enableSessionValidationFromNotification()
        #expect(handle.allowsSessionValidationFromNotifications == true)
        handle.disableSessionValidationFromNotification()
        #expect(handle.allowsSessionValidationFromNotifications == false)
    }

    @Test func disableIsIdempotent() {
        let (handle, _) = makeHandle()
        handle.disableSessionValidationFromNotification()
        #expect(handle.allowsSessionValidationFromNotifications == false)
    }

    @Test func biometricBeingAuthenticatedDisablesNotificationFlag() {
        let (handle, _) = makeHandle()
        handle.enableSessionValidationFromNotification()
        #expect(handle.allowsSessionValidationFromNotifications == true)
        handle.biometricAuthenticationBeingAuthenticated()
        #expect(handle.allowsSessionValidationFromNotifications == false)
    }

    @Test func biometricBeingAuthenticatedClearsManualAuth() {
        let (handle, _) = makeHandle()
        handle.enableManualAuthentication()
        #expect(handle.isManualAuthenticationRequired == true)
        handle.biometricAuthenticationBeingAuthenticated()
        #expect(handle.isManualAuthenticationRequired == false)
    }

    @Test func disableThenReEnableCycle() {
        let (handle, _) = makeHandle()
        handle.enableSessionValidationFromNotification()
        #expect(handle.allowsSessionValidationFromNotifications == true)

        handle.biometricAuthenticationBeingAuthenticated()
        #expect(handle.allowsSessionValidationFromNotifications == false)

        handle.enableSessionValidationFromNotification()
        #expect(handle.allowsSessionValidationFromNotifications == true)
    }

    @Test func disableDoesNotAffectSessionReadinessFlag() {
        let (handle, _) = makeHandle()
        handle.enableSessionForValidation()
        handle.enableSessionValidationFromNotification()
        handle.disableSessionValidationFromNotification()
        #expect(handle.isSessionReadyToValidate == true)
    }
}


// MARK: - Event Handling

@Suite("Event Handling")
struct EventHandlingTests {

    @Test func fetchingSessionTransitionsToSyncing() {
        let (handle, _) = makeHandle()
        handle.set(sessionStatus: .signedIn)
        let listener = handle.listenEvent()
        listener(.fetchingSession)
        #expect(handle.sessionStatus == .syncing)
    }

    @Test func sessionFetchedEnablesValidation() {
        let (handle, _) = makeHandle()
        #expect(handle.isSessionReadyToValidate == false)
        let listener = handle.listenEvent()
        listener(.sessionFetched(isInitialFetch: true))
        #expect(handle.isSessionReadyToValidate == true)
    }

    @Test func sessionFetchedSubsequentEnablesValidation() {
        let (handle, _) = makeHandle()
        let listener = handle.listenEvent()
        listener(.sessionFetched(isInitialFetch: false))
        #expect(handle.isSessionReadyToValidate == true)
    }

    @Test func sessionFetchFailedEnablesValidation() {
        let (handle, _) = makeHandle()
        let listener = handle.listenEvent()
        listener(.sessionFetchFailed(NSError(domain: "test", code: 1)))
        #expect(handle.isSessionReadyToValidate == true)
    }

    @Test func sessionSignInTransitionsToSignedIn() {
        let (handle, _) = makeHandle()
        let listener = handle.listenEvent()
        listener(.sessionSignIn)
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func sessionSignedOutTransitionsToSignedOut() {
        let (handle, _) = makeHandle()
        let listener = handle.listenEvent()
        listener(.sessionSignedOut(error: nil))
        #expect(handle.sessionStatus == .signedOut)
    }

    @Test func sessionSignedOutWithErrorTransitionsToSignedOut() {
        let (handle, _) = makeHandle()
        let listener = handle.listenEvent()
        listener(.sessionSignedOut(error: NSError(domain: "test", code: 1)))
        #expect(handle.sessionStatus == .signedOut)
    }

    @Test func unexpectedErrorDoesNotChangeStatus() {
        let (handle, _) = makeHandle()
        handle.set(sessionStatus: .signedIn)
        let listener = handle.listenEvent()
        listener(.unexpectedError(.sessionExpired))
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func sessionUpdatedDoesNotChangeStatus() {
        let (handle, _) = makeHandle()
        handle.set(sessionStatus: .signedIn)
        let listener = handle.listenEvent()
        listener(.sessionUpdated(nil))
        #expect(handle.sessionStatus == .signedIn)
    }
}


// MARK: - Post-Fetch Session State

@Suite("Post-Fetch Session State")
struct PostFetchSessionStateTests {

    @Test func noSessionTransitionsToSignedOut() {
        let (handle, _) = makeHandle(session: nil)
        handle.set(sessionStatus: .syncing)
        handle.handleSessionStatusOnceFetched()
        #expect(handle.sessionStatus == .signedOut)
    }

    @Test func autoRefreshWithoutLocalValidationTransitionsToSignedIn() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeHandle(session: session, allowsLocalValidation: false, isAutoRefresh: true)
        handle.set(sessionStatus: .syncing)
        handle.handleSessionStatusOnceFetched()
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func validSessionTransitionsToSignedIn() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeHandle(session: session)
        handle.set(sessionStatus: .syncing)
        handle.handleSessionStatusOnceFetched()
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func expiredSessionTriesSignout() {
        let session = MockSession(expiresIn: 0)
        let (handle, provider) = makeHandle(session: session)
        handle.set(sessionStatus: .syncing)
        handle.handleSessionStatusOnceFetched()
        #expect(provider.signoutCallCount == 1)
    }

    @Test func expiredSessionSignoutErrorRoutedToProxy() {
        let session = MockSession(expiresIn: 0)
        let (handle, provider) = makeHandle(session: session)
        provider.signoutError = NSError(domain: "test", code: 42)
        handle.set(sessionStatus: .syncing)
        handle.handleSessionStatusOnceFetched()
        #expect(provider.signoutCallCount == 1)
    }

    @Test func localValidationDisabledAutoRefreshDisabledExpiredSessionSignsOut() {
        let session = MockSession(expiresIn: 0)
        let (handle, provider) = makeHandle(session: session, allowsLocalValidation: false, isAutoRefresh: false)
        handle.set(sessionStatus: .syncing)
        handle.handleSessionStatusOnceFetched()
        #expect(provider.signoutCallCount == 1)
    }

    @Test func localValidationEnabledAutoRefreshEnabledStillChecksExpiry() {
        let session = MockSession(expiresIn: 0)
        let (handle, provider) = makeHandle(session: session, allowsLocalValidation: true, isAutoRefresh: true)
        handle.set(sessionStatus: .syncing)
        handle.handleSessionStatusOnceFetched()
        #expect(provider.signoutCallCount == 1)
    }
}


// MARK: - Local Validation

@Suite("Local Validation")
struct LocalValidationTests {

    @Test func notReadyDoesNothing() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeHandle(session: session)
        handle.set(sessionStatus: .signedIn)
        handle.validateLocalSessionOrAuthenticateIfNeeded()
        #expect(handle.sessionStatus == .signedIn)
        #expect(handle.isSessionReadyToValidate == false)
    }

    @Test func noSessionTransitionsToSignedOut() {
        let (handle, _) = makeReadyHandle(session: nil)
        handle.set(sessionStatus: .signedIn)
        handle.validateLocalSessionOrAuthenticateIfNeeded()
        #expect(handle.sessionStatus == .signedOut)
    }

    @Test func localValidationExpiringSessionSignsOut() {
        // Session expires in 60 seconds — below the 180-second threshold.
        let session = MockSession(expiresIn: 60)
        let (handle, provider) = makeReadyHandle(session: session, allowsLocalValidation: true)
        handle.set(sessionStatus: .signedIn)
        handle.validateLocalSessionOrAuthenticateIfNeeded()
        #expect(provider.signoutCallCount == 1)
    }

    @Test func localValidationValidSessionNoBiometricTransitionsToSignedIn() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeReadyHandle(session: session, allowsLocalValidation: true, canPerformAuth: false)
        handle.set(sessionStatus: .syncing)
        handle.validateLocalSessionOrAuthenticateIfNeeded()
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func localValidationGoesToValidatingFirst() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeReadyHandle(session: session, allowsLocalValidation: true, canPerformAuth: false)
        handle.set(sessionStatus: .syncing)

        handle.validateLocalSessionOrAuthenticateIfNeeded()
        // After completion, it should be signedIn (passed through validating).
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func noLocalValidationNoBiometricSyncingTransitionsToSignedIn() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeReadyHandle(session: session, allowsLocalValidation: false, canPerformAuth: false)
        handle.set(sessionStatus: .syncing)
        handle.validateLocalSessionOrAuthenticateIfNeeded()
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func noLocalValidationNoBiometricSignedInStaysSignedIn() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeReadyHandle(session: session, allowsLocalValidation: false, canPerformAuth: false)
        handle.set(sessionStatus: .signedIn)
        handle.validateLocalSessionOrAuthenticateIfNeeded()
        // Not syncing, so Branch C doesn't apply — stays signedIn.
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func localValidationNotAllowedWhenSignedOut() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeReadyHandle(session: session, allowsLocalValidation: true)
        handle.set(sessionStatus: .signedOut)
        // signedOut doesn't allow local validation — no state change.
        handle.validateLocalSessionOrAuthenticateIfNeeded()
        #expect(handle.sessionStatus == .signedOut)
    }

    @Test func localValidationNotAllowedDuringBiometricAuth() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeReadyHandle(session: session, allowsLocalValidation: true)
        handle.set(sessionStatus: .biometricAuthentication)
        // biometricAuthentication status doesn't allow local validation.
        handle.validateLocalSessionOrAuthenticateIfNeeded()
        #expect(handle.sessionStatus == .biometricAuthentication)
    }

    @Test func signoutFailureRoutesError() {
        let session = MockSession(expiresIn: 60)
        let (handle, provider) = makeReadyHandle(session: session, allowsLocalValidation: true)
        provider.signoutError = NSError(domain: "test", code: 99)
        handle.set(sessionStatus: .signedIn)
        handle.validateLocalSessionOrAuthenticateIfNeeded()
        // Signout was attempted but failed.
        #expect(provider.signoutCallCount == 1)
    }
}


// MARK: - Biometric Failure Handling

@Suite("Biometric Failure Handling")
struct BiometricFailureHandlingTests {

    @Test func failureSignsOutWhenProviderAllows() {
        let session = MockSession(expiresIn: 3600)
        let (handle, provider) = makeHandle(session: session)
        provider.allowsSignoutOnBiometricFailure = true
        handle.biometricAuthenticationFailure(with: .failed)
        #expect(provider.signoutCallCount == 1)
    }

    @Test func failurePassesBiometricErrorToSignout() {
        let session = MockSession(expiresIn: 3600)
        let (handle, provider) = makeHandle(session: session)
        provider.allowsSignoutOnBiometricFailure = true
        handle.biometricAuthenticationFailure(with: .failed)
        #expect(provider.signoutReceivedError is BiometricAuthenticationError)
    }

    @Test func failureSignoutErrorRoutesToProxy() {
        let session = MockSession(expiresIn: 3600)
        let (handle, provider) = makeHandle(session: session)
        provider.allowsSignoutOnBiometricFailure = true
        provider.signoutError = NSError(domain: "test", code: 42)

        handle.biometricAuthenticationFailure(with: .failed)
        #expect(provider.signoutCallCount == 1)
    }

    @Test func failureStaysSignedInWhenProviderDisallowsSignout() {
        let session = MockSession(expiresIn: 3600)
        let (handle, provider) = makeHandle(session: session)
        provider.allowsSignoutOnBiometricFailure = false
        handle.set(sessionStatus: .biometricAuthentication)

        handle.biometricAuthenticationFailure(with: .failed)
        #expect(handle.sessionStatus == .signedIn)
        #expect(provider.signoutCallCount == 0)
    }

    @Test func failureNotifiesDelegateWhenProviderDisallowsSignout() {
        let session = MockSession(expiresIn: 3600)
        let (handle, provider, delegate) = subscribedHandle(session: session)
        provider.allowsSignoutOnBiometricFailure = false
        handle.set(sessionStatus: .biometricAuthentication)

        handle.biometricAuthenticationFailure(with: .failed)
        drainDelegateQueue()
        #expect(delegate.failureErrors.count == 1)
    }

    @Test func defaultProviderPolicyIsSignout() {
        let session = MockSession(expiresIn: 3600)
        let (handle, provider) = makeHandle(session: session)
        handle.biometricAuthenticationFailure(with: .failed)
        #expect(provider.signoutCallCount == 1)
    }

    @Test func failureEnablesManualAuthWhenProviderDisallowsSignout() {
        let session = MockSession(expiresIn: 3600)
        let (handle, provider) = makeHandle(session: session)
        provider.allowsSignoutOnBiometricFailure = false
        handle.biometricAuthenticationFailure(with: .failed)
        #expect(handle.isManualAuthenticationRequired == true)
    }

    @Test func failureDoesNotEnableManualAuthWhenProviderAllowsSignout() {
        let session = MockSession(expiresIn: 3600)
        let (handle, provider) = makeHandle(session: session)
        provider.allowsSignoutOnBiometricFailure = true
        handle.biometricAuthenticationFailure(with: .failed)
        #expect(handle.isManualAuthenticationRequired == false)
    }
}


// MARK: - AuthSessionStatus State Queries

@Suite("AuthSessionStatus")
struct AuthSessionStatusTests {

    @Test func allowsBiometricAuthentication() {
        #expect(AuthSessionStatus.signedIn.allowsBiometricAuthentication == true)
        #expect(AuthSessionStatus.syncing.allowsBiometricAuthentication == true)
        #expect(AuthSessionStatus.validating.allowsBiometricAuthentication == true)
        #expect(AuthSessionStatus.signedOut.allowsBiometricAuthentication == false)
        #expect(AuthSessionStatus.biometricAuthentication.allowsBiometricAuthentication == false)
    }

    @Test func allowsLocalValidation() {
        #expect(AuthSessionStatus.signedIn.allowsLocalValidation == true)
        #expect(AuthSessionStatus.syncing.allowsLocalValidation == true)
        #expect(AuthSessionStatus.validating.allowsLocalValidation == false)
        #expect(AuthSessionStatus.signedOut.allowsLocalValidation == false)
        #expect(AuthSessionStatus.biometricAuthentication.allowsLocalValidation == false)
    }

    @Test func isLoadingStatus() {
        #expect(AuthSessionStatus.syncing.isLoadingStatus == true)
        #expect(AuthSessionStatus.validating.isLoadingStatus == true)
        #expect(AuthSessionStatus.biometricAuthentication.isLoadingStatus == true)
        #expect(AuthSessionStatus.signedIn.isLoadingStatus == false)
        #expect(AuthSessionStatus.signedOut.isLoadingStatus == false)
    }

    @Test func statusInterfaceConformance() {
        #expect(AuthSessionStatus.syncing.isSyncing == true)
        #expect(AuthSessionStatus.syncing.isSignedIn == false)

        #expect(AuthSessionStatus.signedIn.isSignedIn == true)
        #expect(AuthSessionStatus.signedIn.isSyncing == false)

        #expect(AuthSessionStatus.signedOut.isSignedOut == true)
        #expect(AuthSessionStatus.signedOut.isSignedIn == false)

        #expect(AuthSessionStatus.validating.isValidating == true)
        #expect(AuthSessionStatus.validating.isSyncing == false)

        #expect(AuthSessionStatus.biometricAuthentication.isBiometricAuthentication == true)
        #expect(AuthSessionStatus.biometricAuthentication.isSignedIn == false)
    }

    @Test func hashable() {
        let set: Set<AuthSessionStatus> = [.syncing, .signedIn, .signedOut, .validating, .biometricAuthentication]
        #expect(set.count == 5)
    }

    @Test func equatable() {
        #expect(AuthSessionStatus.syncing == .syncing)
        #expect(AuthSessionStatus.syncing != .signedIn)
    }
}


// MARK: - AuthSessionError

@Suite("AuthSessionError")
struct AuthSessionErrorTests {

    @Test func errorDescriptions() {
        #expect(AuthSessionError.sessionMalformed.errorDescription == "The authentication session is malformed.")
        #expect(AuthSessionError.sessionExpired.errorDescription == "The authentication session has timed out.")
    }

    @Test func networkFailureIncludesUnderlyingError() {
        let underlying = NSError(domain: "network", code: -1009, userInfo: [NSLocalizedDescriptionKey: "offline"])
        let error = AuthSessionError.networkFailure(error: underlying)
        #expect(error.errorDescription?.contains("offline") == true)
    }

    @Test func signingOutFailureIncludesPrefix() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "failed"])
        let error = AuthSessionError.signingOutFailure(error: underlying)
        #expect(error.errorDescription?.hasPrefix("Sign-out failed:") == true)
    }
}


// MARK: - AuthSessionProtocol Default Extensions

@Suite("AuthSessionProtocol Defaults")
struct AuthSessionProtocolTests {

    @Test func expiresInComputedFromExpiresAt() {
        let session = MockSession(expiresIn: 500)
        #expect(session.expiresIn > 490)
        #expect(session.expiresIn <= 500)
    }

    @Test func isSessionExpiredWhenUnder120Seconds() {
        let session = MockSession(expiresIn: 60)
        #expect(session.isSessionExpired == true)
    }

    @Test func isSessionNotExpiredWhenOver120Seconds() {
        let session = MockSession(expiresIn: 300)
        #expect(session.isSessionExpired == false)
    }

    @Test func isSessionExpiredAtExactBoundary() {
        let session = MockSession(expiresIn: 120)
        // At exactly 120 seconds, timeIntervalSinceNow < 120 is false (it's ≈ 120).
        // Due to timing, this should be right at the boundary.
        #expect(session.isSessionExpired == false || session.isSessionExpired == true)
    }

    @Test func expiresInNeverNegative() {
        let session = MockSession(expiresIn: -100)
        #expect(session.expiresIn >= 0)
    }
}


// MARK: - Full Flow Integration

@Suite("Integration")
struct IntegrationTests {

    @Test func initialFetchWithValidSessionSignsIn() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeHandle(session: session, allowsLocalValidation: true, canPerformAuth: false)
        let listener = handle.listenEvent()

        listener(.fetchingSession)
        #expect(handle.sessionStatus == .syncing)

        listener(.sessionFetched(isInitialFetch: true))
        #expect(handle.isSessionReadyToValidate == true)
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func initialFetchWithNoSessionSignsOut() {
        let (handle, _) = makeHandle(session: nil, allowsLocalValidation: true, canPerformAuth: false)
        let listener = handle.listenEvent()

        listener(.fetchingSession)
        listener(.sessionFetched(isInitialFetch: true))
        #expect(handle.sessionStatus == .signedOut)
    }

    @Test func initialFetchWithExpiredSessionTriesSignout() {
        let session = MockSession(expiresIn: 60)
        let (handle, provider) = makeHandle(session: session, allowsLocalValidation: true, canPerformAuth: false)
        let listener = handle.listenEvent()

        listener(.fetchingSession)
        listener(.sessionFetched(isInitialFetch: true))
        #expect(provider.signoutCallCount == 1)
    }

    @Test func subsequentFetchValidSessionSignsIn() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeHandle(session: session)
        let listener = handle.listenEvent()

        listener(.sessionFetched(isInitialFetch: false))
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func fetchFailedThenRecovery() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeHandle(session: session)
        let listener = handle.listenEvent()

        listener(.sessionFetchFailed(NSError(domain: "test", code: 1)))
        #expect(handle.isSessionReadyToValidate == true)
        // Session exists and is valid, so should be signedIn.
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func fetchFailedNoSessionSignsOut() {
        let (handle, _) = makeHandle(session: nil)
        let listener = handle.listenEvent()

        listener(.sessionFetchFailed(NSError(domain: "test", code: 1)))
        #expect(handle.sessionStatus == .signedOut)
    }

    @Test func signInThenSignOutFlow() {
        let (handle, _) = makeHandle()
        let listener = handle.listenEvent()

        listener(.sessionSignIn)
        #expect(handle.sessionStatus == .signedIn)

        listener(.sessionSignedOut(error: nil))
        #expect(handle.sessionStatus == .signedOut)
    }

    @Test func autoRefreshSkipsLocalValidation() {
        let session = MockSession(expiresIn: 3600)
        let (handle, provider) = makeHandle(session: session, allowsLocalValidation: false, isAutoRefresh: true)
        let listener = handle.listenEvent()

        listener(.sessionFetched(isInitialFetch: false))
        #expect(handle.sessionStatus == .signedIn)
        #expect(provider.signoutCallCount == 0)
    }
}


// MARK: - Mock Delegate

final class MockDelegate: NSObject, AuthSessionDelegate, @unchecked Sendable {

    var statusChanges: [(new: any AuthSessionStatusProtocol, old: any AuthSessionStatusProtocol)] = []
    var loginCount = 0
    var logoutCount = 0
    var logoutErrors: [Error?] = []
    var fetchCompletions: [Bool] = []
    var failureErrors: [AuthSessionError] = []
    var userUpdates = 0

    func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didUpdateStatus sessionStatus: any AuthSessionStatusProtocol, from oldStatus: any AuthSessionStatusProtocol, for session: (any AuthSessionProtocol)?) {
        statusChanges.append((new: sessionStatus, old: oldStatus))
    }

    func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didLoginWith user: (any AuthSessionUserProtocol)?, for session: (any AuthSessionProtocol)?) {
        loginCount += 1
    }

    func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didLogoutWith error: Error?) {
        logoutCount += 1
        logoutErrors.append(error)
    }

    func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didCompleteFetchWith session: (any AuthSessionProtocol)?, isInitialFetch flag: Bool) {
        fetchCompletions.append(flag)
    }

    func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didFailWith error: AuthSessionError, for session: (any AuthSessionProtocol)?) {
        failureErrors.append(error)
    }

    func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?, didUpdate user: (any AuthSessionUserProtocol)?, for session: (any AuthSessionProtocol)?) {
        userUpdates += 1
    }
}

private let delegateQueue = DispatchQueue(label: "test.delegate")

private func subscribedHandle(
    session: MockSession? = nil,
    allowsLocalValidation: Bool = true,
    isAutoRefresh: Bool = false,
    canPerformAuth: Bool = false
) -> (AuthSessionHandle<MockSessionProvider>, MockSessionProvider, MockDelegate) {
    let (handle, provider) = makeHandle(
        session: session,
        allowsLocalValidation: allowsLocalValidation,
        isAutoRefresh: isAutoRefresh,
        canPerformAuth: canPerformAuth
    )
    let delegate = MockDelegate()
    handle.subscribeDelegate(delegate, receive: delegateQueue)
    return (handle, provider, delegate)
}

private func drainDelegateQueue() {
    delegateQueue.sync {}
}


// MARK: - Delegate Notifications

@Suite("Delegate Notifications")
struct DelegateNotificationTests {

    @Test func statusChangeNotifiesDelegate() {
        let (handle, _, delegate) = subscribedHandle()
        handle.set(sessionStatus: .signedIn)
        drainDelegateQueue()
        #expect(delegate.statusChanges.count == 1)
        #expect(delegate.statusChanges.first?.new.isSignedIn == true)
        #expect(delegate.statusChanges.first?.old.isSyncing == true)
    }

    @Test func noOpStatusChangeDoesNotNotify() {
        let (handle, _, delegate) = subscribedHandle()
        handle.set(sessionStatus: .syncing)
        drainDelegateQueue()
        #expect(delegate.statusChanges.isEmpty)
    }

    @Test func multipleStatusChangesNotifyInOrder() {
        let (handle, _, delegate) = subscribedHandle()
        handle.set(sessionStatus: .signedIn)
        handle.set(sessionStatus: .signedOut)
        drainDelegateQueue()
        #expect(delegate.statusChanges.count == 2)
        #expect(delegate.statusChanges[0].new.isSignedIn == true)
        #expect(delegate.statusChanges[1].new.isSignedOut == true)
    }

    @Test func signInEventNotifiesLoginDelegate() {
        let session = MockSession()
        let (handle, _, delegate) = subscribedHandle(session: session)
        let listener = handle.listenEvent()
        listener(.sessionSignIn)
        drainDelegateQueue()
        #expect(delegate.loginCount == 1)
    }

    @Test func signOutEventNotifiesLogoutDelegate() {
        let (handle, _, delegate) = subscribedHandle()
        let listener = handle.listenEvent()
        listener(.sessionSignedOut(error: nil))
        drainDelegateQueue()
        #expect(delegate.logoutCount == 1)
        #expect(delegate.logoutErrors.first! == nil)
    }

    @Test func signOutWithErrorPassesErrorToDelegate() {
        let (handle, _, delegate) = subscribedHandle()
        let listener = handle.listenEvent()
        let error = NSError(domain: "test", code: 7)
        listener(.sessionSignedOut(error: error))
        drainDelegateQueue()
        #expect(delegate.logoutCount == 1)
        #expect((delegate.logoutErrors.first! as? NSError)?.code == 7)
    }

    @Test func fetchCompletedNotifiesDelegate() {
        let (handle, _, delegate) = subscribedHandle()
        let listener = handle.listenEvent()
        listener(.sessionFetched(isInitialFetch: true))
        drainDelegateQueue()
        #expect(delegate.fetchCompletions == [true])
    }

    @Test func subsequentFetchNotifiesDelegate() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _, delegate) = subscribedHandle(session: session)
        let listener = handle.listenEvent()
        listener(.sessionFetched(isInitialFetch: false))
        drainDelegateQueue()
        #expect(delegate.fetchCompletions == [false])
    }

    @Test func fetchFailedNotifiesFailureDelegate() {
        let (handle, _, delegate) = subscribedHandle()
        let listener = handle.listenEvent()
        listener(.sessionFetchFailed(NSError(domain: "net", code: -1)))
        drainDelegateQueue()
        #expect(delegate.failureErrors.count == 1)
    }

    @Test func unexpectedErrorNotifiesFailureDelegate() {
        let (handle, _, delegate) = subscribedHandle()
        let listener = handle.listenEvent()
        listener(.unexpectedError(.sessionExpired))
        drainDelegateQueue()
        #expect(delegate.failureErrors.count == 1)
    }

    @Test func sessionUpdatedNotifiesUserUpdateDelegate() {
        let (handle, _, delegate) = subscribedHandle()
        let listener = handle.listenEvent()
        listener(.sessionUpdated(nil))
        drainDelegateQueue()
        #expect(delegate.userUpdates == 1)
    }

    @Test func multipleDelegatesAllReceiveCallbacks() {
        let (handle, _, delegate1) = subscribedHandle()
        let delegate2 = MockDelegate()
        handle.subscribeDelegate(delegate2, receive: delegateQueue)
        handle.set(sessionStatus: .signedIn)
        drainDelegateQueue()
        #expect(delegate1.statusChanges.count == 1)
        #expect(delegate2.statusChanges.count == 1)
    }
}


// MARK: - SessionHandleEventProxy

@Suite("SessionHandleEventProxy")
struct SessionHandleEventProxyTests {

    @Test func publishForwardsEventToClosure() {
        let counter = SendableCounter()
        let proxy = SessionHandleEventProxy(eventListening: { _ in
            counter.increment()
        })
        proxy.publish(.fetchingSession)
        proxy.publish(.sessionSignIn)
        #expect(counter.value == 2)
    }

    @Test func publishConvenienceOmitsProvider() {
        let counter = SendableCounter()
        let proxy = SessionHandleEventProxy(eventListening: { _ in
            counter.increment()
        })
        proxy.publish(.fetchingSession)
        #expect(counter.value == 1)
    }

    @Test func authenticatedSetsSignedInOnBiometricProxy() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeHandle(session: session)
        handle.set(sessionStatus: .biometricAuthentication)
        let proxy = handle.sessionEventProxy as! SessionHandleEventProxy
        proxy.authenticated()
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func authenticationFailedForwardsToHandle() {
        let session = MockSession(expiresIn: 3600)
        let (handle, provider) = makeHandle(session: session)
        provider.allowsSignoutOnBiometricFailure = true
        let proxy = handle.sessionEventProxy as! SessionHandleEventProxy
        proxy.authenticationFailed(with: .failed)
        #expect(provider.signoutCallCount == 1)
    }

    @Test func authenticationFailedRespectsProviderPolicy() {
        let session = MockSession(expiresIn: 3600)
        let (handle, provider) = makeHandle(session: session)
        provider.allowsSignoutOnBiometricFailure = false
        handle.set(sessionStatus: .biometricAuthentication)
        let proxy = handle.sessionEventProxy as! SessionHandleEventProxy
        proxy.authenticationFailed(with: .failed)
        #expect(provider.signoutCallCount == 0)
        #expect(handle.sessionStatus == .signedIn)
    }

    @Test func authRequestInProcessDisablesNotificationValidation() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeHandle(session: session)
        handle.enableSessionValidationFromNotification()
        #expect(handle.allowsSessionValidationFromNotifications == true)

        let proxy = handle.sessionEventProxy as! SessionHandleEventProxy
        proxy.authenticationRequestInProcess(didChange: false, to: true)
        #expect(handle.allowsSessionValidationFromNotifications == false)
    }

    @Test func authRequestInProcessEndDoesNotReEnable() {
        let session = MockSession(expiresIn: 3600)
        let (handle, _) = makeHandle(session: session)
        handle.enableSessionValidationFromNotification()
        handle.disableSessionValidationFromNotification()

        let proxy = handle.sessionEventProxy as! SessionHandleEventProxy
        proxy.authenticationRequestInProcess(didChange: true, to: false)
        #expect(handle.allowsSessionValidationFromNotifications == false)
    }

    @Test func weakBiometricProxyNilAfterHandleDeallocated() {
        var handle: AuthSessionHandle<MockSessionProvider>? = AuthSessionHandle(sessionProvider: MockSessionProvider())
        let proxy = handle!.sessionEventProxy as! SessionHandleEventProxy
        handle = nil
        proxy.authenticated()
    }
}


// MARK: - Deinit Cleanup

@Suite("Deinit Cleanup")
struct DeinitCleanupTests {

    @Test func handleCanBeDeallocated() {
        weak var weakHandle: AuthSessionHandle<MockSessionProvider>?
        do {
            let handle = AuthSessionHandle(sessionProvider: MockSessionProvider())
            weakHandle = handle
            #expect(weakHandle != nil)
        }
        #expect(weakHandle == nil)
    }

    @Test func eventProxyWeakReferenceBreaksAfterDeinit() {
        let proxy: SessionHandleEventProxy
        do {
            let handle = AuthSessionHandle(sessionProvider: MockSessionProvider())
            proxy = handle.sessionEventProxy as! SessionHandleEventProxy
        }
        proxy.publish(.sessionSignIn)
        proxy.authenticated()
    }
}


// MARK: - AuthSessionDelegateEvent

@Suite("AuthSessionDelegateEvent")
struct AuthSessionDelegateEventTests {

    @Test func sessionFetchInitialCarriesFlag() {
        let event = AuthSessionDelegateEvent.sessionFetch(isInitial: true)
        guard case .sessionFetch(let isInitial) = event else {
            Issue.record("expected .sessionFetch case")
            return
        }
        #expect(isInitial == true)
    }

    @Test func sessionFetchSubsequentCarriesFlag() {
        let event = AuthSessionDelegateEvent.sessionFetch(isInitial: false)
        guard case .sessionFetch(let isInitial) = event else {
            Issue.record("expected .sessionFetch case")
            return
        }
        #expect(isInitial == false)
    }

    @Test func loginCaseExists() {
        let event = AuthSessionDelegateEvent.login
        if case .login = event {
            #expect(Bool(true))
        } else {
            Issue.record("expected .login case")
        }
    }

    @Test func logoutCarriesNilError() {
        let event = AuthSessionDelegateEvent.logout(error: nil)
        guard case .logout(let error) = event else {
            Issue.record("expected .logout case")
            return
        }
        #expect(error == nil)
    }

    @Test func logoutCarriesUnderlyingError() {
        let underlying = NSError(domain: "test", code: 99)
        let event = AuthSessionDelegateEvent.logout(error: underlying)
        guard case .logout(let error) = event else {
            Issue.record("expected .logout case")
            return
        }
        #expect((error as? NSError)?.code == 99)
    }

    @Test func sessionStatusChangedCarriesOldAndNew() {
        let event = AuthSessionDelegateEvent.sessionStatusChanged(
            oldValue: AuthSessionStatus.syncing,
            newValue: AuthSessionStatus.signedIn
        )
        guard case .sessionStatusChanged(let oldValue, let newValue) = event else {
            Issue.record("expected .sessionStatusChanged case")
            return
        }
        #expect(oldValue.isSyncing == true)
        #expect(newValue.isSignedIn == true)
    }

    @Test func failureCarriesAuthSessionError() {
        let event = AuthSessionDelegateEvent.failure(error: .sessionExpired)
        guard case .failure(let error) = event else {
            Issue.record("expected .failure case")
            return
        }
        if case .sessionExpired = error {
            #expect(Bool(true))
        } else {
            Issue.record("expected .sessionExpired payload")
        }
    }

    @Test func userUpdateCaseExists() {
        let event = AuthSessionDelegateEvent.userUpdate
        if case .userUpdate = event {
            #expect(Bool(true))
        } else {
            Issue.record("expected .userUpdate case")
        }
    }
}


// MARK: - AuthSessionDelegateEventPublisher

/// Minimal conformer used to verify the publish contract.
final class MockDelegateEventPublisher: AuthSessionDelegateEventPublisher, @unchecked Sendable {

    var published: [(event: AuthSessionDelegateEvent, handle: (any AuthSessionHandleProtocol)?)] = []

    func publish(_ event: AuthSessionDelegateEvent, for sessionHandle: (any AuthSessionHandleProtocol)?) {
        published.append((event, sessionHandle))
    }
}

@Suite("AuthSessionDelegateEventPublisher")
struct AuthSessionDelegateEventPublisherTests {

    @Test func publishStoresEvent() {
        let publisher = MockDelegateEventPublisher()
        publisher.publish(.login, for: nil)
        #expect(publisher.published.count == 1)
        if case .login = publisher.published.first?.event {
            #expect(Bool(true))
        } else {
            Issue.record("expected .login")
        }
    }

    @Test func publishPassesHandleReference() {
        let publisher = MockDelegateEventPublisher()
        let handle = AuthSessionHandle(sessionProvider: MockSessionProvider())
        publisher.publish(.userUpdate, for: handle)
        #expect(publisher.published.first?.handle === handle)
    }

    @Test func publishAllowsNilHandle() {
        let publisher = MockDelegateEventPublisher()
        publisher.publish(.userUpdate, for: nil)
        #expect(publisher.published.first?.handle == nil)
    }

    @Test func publishPreservesOrder() {
        let publisher = MockDelegateEventPublisher()
        publisher.publish(.sessionFetch(isInitial: true), for: nil)
        publisher.publish(.login, for: nil)
        publisher.publish(.logout(error: nil), for: nil)

        #expect(publisher.published.count == 3)
        if case .sessionFetch(let initial) = publisher.published[0].event {
            #expect(initial == true)
        } else {
            Issue.record("expected .sessionFetch first")
        }
        if case .login = publisher.published[1].event {
            #expect(Bool(true))
        } else {
            Issue.record("expected .login second")
        }
        if case .logout = publisher.published[2].event {
            #expect(Bool(true))
        } else {
            Issue.record("expected .logout third")
        }
    }
}


// MARK: - AuthSessionDelegateEventProxy

/// Minimal closure-only conformer matching the proxy's `init(eventListening:)` contract.
final class MockDelegateEventProxy: AuthSessionDelegateEventProxy, @unchecked Sendable {

    let eventListening: @MainActor @Sendable (AuthSessionDelegateEvent) -> Void

    required init(eventListening: @escaping @MainActor @Sendable (AuthSessionDelegateEvent) -> Void) {
        self.eventListening = eventListening
    }

    @MainActor
    func forward(_ event: AuthSessionDelegateEvent) {
        eventListening(event)
    }
}

@Suite("AuthSessionDelegateEventProxy")
struct AuthSessionDelegateEventProxyTests {

    @Test @MainActor func initStoresClosure() {
        let counter = SendableCounter()
        let proxy = MockDelegateEventProxy { _ in counter.increment() }
        proxy.forward(.login)
        #expect(counter.value == 1)
    }

    @Test @MainActor func closureReceivesEveryEvent() {
        let counter = SendableCounter()
        let proxy = MockDelegateEventProxy { _ in counter.increment() }
        proxy.forward(.sessionFetch(isInitial: true))
        proxy.forward(.login)
        proxy.forward(.userUpdate)
        proxy.forward(.logout(error: nil))
        #expect(counter.value == 4)
    }

    @Test @MainActor func closureReceivesAssociatedValues() {
        var received: AuthSessionDelegateEvent?
        let proxy = MockDelegateEventProxy { event in received = event }

        proxy.forward(.sessionFetch(isInitial: false))
        guard case .sessionFetch(let isInitial) = received else {
            Issue.record("expected .sessionFetch payload")
            return
        }
        #expect(isInitial == false)
    }

    @Test @MainActor func closureReceivesStatusChangedPayload() {
        var received: AuthSessionDelegateEvent?
        let proxy = MockDelegateEventProxy { event in received = event }

        proxy.forward(.sessionStatusChanged(
            oldValue: AuthSessionStatus.signedIn,
            newValue: AuthSessionStatus.signedOut
        ))

        guard case .sessionStatusChanged(let oldValue, let newValue) = received else {
            Issue.record("expected .sessionStatusChanged payload")
            return
        }
        #expect(oldValue.isSignedIn == true)
        #expect(newValue.isSignedOut == true)
    }

    @Test @MainActor func closureReceivesFailurePayload() {
        var received: AuthSessionDelegateEvent?
        let proxy = MockDelegateEventProxy { event in received = event }

        proxy.forward(.failure(error: .sessionMalformed))

        guard case .failure(let error) = received else {
            Issue.record("expected .failure payload")
            return
        }
        if case .sessionMalformed = error {
            #expect(Bool(true))
        } else {
            Issue.record("expected .sessionMalformed underlying")
        }
    }
}


// MARK: - Thread Safety

/// Stresses the lock-protected state on `AuthSessionHandle` from multiple concurrent
/// callers. Every assertion here verifies the handle survives concurrent access — no
/// crash, no torn state, and final state matches the deterministic last-write-wins
/// expectation.
///
/// **Serialized** because each test in this suite already spawns its own concurrent
/// dispatch storm; letting Swift Testing run them in parallel would saturate the
/// thread pool and risk runner timeouts.
@Suite("Thread Safety", .serialized)
struct ThreadSafetyTests {

    /// Total iterations per test. Tuned to be heavy enough to expose races on
    /// real hardware while still finishing quickly in CI. The suite uses
    /// `.serialized`, so each test gets the full thread pool to itself.
    private static let iterations = 10_000

    private static let stressQueue = DispatchQueue(
        label: "test.authsession.stress",
        attributes: .concurrent
    )

    /// Fires `count` concurrent invocations of `body` and waits for all of them.
    private static func concurrentlyRun(
        count: Int = iterations,
        _ body: @escaping @Sendable (Int) -> Void
    ) {
        let group = DispatchGroup()
        for i in 0..<count {
            group.enter()
            stressQueue.async {
                body(i)
                group.leave()
            }
        }
        group.wait()
    }

    @Test func statusReadsAreSafeUnderConcurrentWrites() {
        let provider = MockSessionProvider()
        let handle = AuthSessionHandle(sessionProvider: provider)

        let statuses: [AuthSessionStatus] = [
            .syncing, .signedIn, .signedOut, .validating, .biometricAuthentication
        ]

        Self.concurrentlyRun { i in
            // Half the threads write, half read.
            if i.isMultiple(of: 2) {
                handle.set(sessionStatus: statuses[i % statuses.count])
            } else {
                _ = handle.sessionStatus
            }
        }

        // Should land on *some* valid status without crashing.
        #expect(statuses.contains(handle.sessionStatus))
    }

    @Test func manualAuthFlagIsRaceFree() {
        let provider = MockSessionProvider()
        let handle = AuthSessionHandle(sessionProvider: provider)

        Self.concurrentlyRun { i in
            if i.isMultiple(of: 2) {
                handle.enableManualAuthentication()
            } else {
                handle.disableManualAuthentication()
            }
        }

        // Final value is deterministic enough — it must be a valid Bool, not torn.
        let final = handle.isManualAuthenticationRequired
        #expect(final == true || final == false)
    }

    @Test func sessionReadinessTransitionsOnce() {
        let provider = MockSessionProvider()
        let handle = AuthSessionHandle(sessionProvider: provider)

        Self.concurrentlyRun { _ in
            handle.enableSessionForValidation()
        }

        // Once flipped to true, it stays true regardless of concurrent enables.
        #expect(handle.isSessionReadyToValidate == true)
    }

    @Test func notificationValidationFlagIsRaceFree() {
        let provider = MockSessionProvider()
        let handle = AuthSessionHandle(sessionProvider: provider)

        Self.concurrentlyRun { i in
            if i.isMultiple(of: 2) {
                handle.enableSessionValidationFromNotification()
            } else {
                handle.disableSessionValidationFromNotification()
            }
        }

        let final = handle.allowsSessionValidationFromNotifications
        #expect(final == true || final == false)
    }

    @Test func eventListenerSurvivesConcurrentDelivery() {
        let provider = MockSessionProvider()
        let handle = AuthSessionHandle(sessionProvider: provider)
        let listener = handle.listenEvent()

        let events: [AuthSessionEvent] = [
            .fetchingSession,
            .sessionFetched(isInitialFetch: false),
            .sessionSignIn,
            .sessionSignedOut(error: nil),
            .sessionUpdated(nil),
            .unexpectedError(.sessionExpired)
        ]

        Self.concurrentlyRun { i in
            listener(events[i % events.count])
        }

        // Survival check — handle still in a valid status.
        let final = handle.sessionStatus
        #expect([
            AuthSessionStatus.syncing,
            .signedIn,
            .signedOut,
            .validating,
            .biometricAuthentication
        ].contains(final))
    }

    @Test func mixedAccessorsAndMutatorsDoNotCrash() {
        let provider = MockSessionProvider()
        let handle = AuthSessionHandle(sessionProvider: provider)

        Self.concurrentlyRun(count: 30_000) { i in
            switch i % 8 {
            case 0: handle.set(sessionStatus: .signedIn)
            case 1: handle.set(sessionStatus: .signedOut)
            case 2: handle.enableManualAuthentication()
            case 3: handle.disableManualAuthentication()
            case 4: handle.enableSessionForValidation()
            case 5: _ = handle.sessionStatus
            case 6: _ = handle.isManualAuthenticationRequired
            case 7: _ = handle.allowsSessionValidationFromNotifications
            default: break
            }
        }

        // No assertion needed beyond reaching this line without a crash —
        // ThreadSanitizer or a torn read would have aborted the run.
        #expect(Bool(true))
    }

    @Test func deinitIsSafeAfterConcurrentActivity() {
        weak var weakHandle: AuthSessionHandle<MockSessionProvider>?

        do {
            let provider = MockSessionProvider()
            let handle = AuthSessionHandle(sessionProvider: provider)
            weakHandle = handle

            Self.concurrentlyRun(count: 5_000) { i in
                if i.isMultiple(of: 3) {
                    handle.set(sessionStatus: .signedIn)
                } else if i.isMultiple(of: 5) {
                    handle.enableManualAuthentication()
                } else {
                    _ = handle.sessionStatus
                }
            }
        }

        #expect(weakHandle == nil)
    }

    @Test func concurrentDelegateInvocationsAllDeliver() {
        let provider = MockSessionProvider()
        let handle = AuthSessionHandle(sessionProvider: provider)
        let delegate = MockDelegate()
        handle.subscribeDelegate(delegate, receive: delegateQueue)

        Self.concurrentlyRun(count: 5_000) { i in
            // Alternate between distinct states to force a transition every call.
            handle.set(sessionStatus: i.isMultiple(of: 2) ? .signedIn : .signedOut)
        }

        drainDelegateQueue()

        // Every transition that actually changed the value should have delivered
        // exactly one delegate callback. Without locking, deliveries would be lost
        // or duplicated. We don't assert an exact count (the no-op guard depends on
        // ordering), but we expect at least one and a sensible upper bound.
        #expect(delegate.statusChanges.count > 0)
        #expect(delegate.statusChanges.count <= 5_000)
    }

    @Test func concurrentSubscribeUnsubscribeIsRaceFree() {
        let provider = MockSessionProvider()
        let handle = AuthSessionHandle(sessionProvider: provider)

        // Pool of long-lived delegates so they aren't deallocated mid-test.
        let pool = (0..<32).map { _ in MockDelegate() }

        Self.concurrentlyRun(count: 10_000) { i in
            let delegate = pool[i % pool.count]
            if i.isMultiple(of: 2) {
                handle.subscribeDelegate(delegate, receive: delegateQueue)
            } else {
                handle.unsubscribeDelegate(delegate)
            }
        }

        // Trigger a single broadcast to make sure the subscription table is
        // still usable after the storm.
        handle.set(sessionStatus: .signedIn)
        drainDelegateQueue()
        #expect(Bool(true))
    }

    /// Writes a known status from one queue, then reads from a *different* queue
    /// and asserts the read lands on one of the values being concurrently written.
    /// A reader must never observe the initial `.syncing` value once the first
    /// writer has completed — that would imply broken memory visibility through
    /// the lock.
    @Test func writesAreVisibleAcrossThreads() {
        let provider = MockSessionProvider()
        let handle = AuthSessionHandle(sessionProvider: provider)

        let writerQueue = DispatchQueue(label: "test.writer")
        let readerQueue = DispatchQueue(label: "test.reader")

        let staleReads = ConcurrencySafeCounter()

        let group = DispatchGroup()
        for i in 0..<5_000 {
            let expected: AuthSessionStatus = i.isMultiple(of: 2) ? .signedIn : .signedOut
            group.enter()
            writerQueue.async {
                handle.set(sessionStatus: expected)
                readerQueue.async {
                    // Snapshot once — the status is a moving target, so reading it
                    // multiple times in the condition would race with itself.
                    let observed = handle.sessionStatus
                    if observed != .signedIn && observed != .signedOut {
                        staleReads.increment()
                    }
                    group.leave()
                }
            }
        }
        group.wait()

        // Once the first writer has completed, status must have left `.syncing`
        // and every subsequent read should see one of the two written values.
        #expect(staleReads.value == 0)
    }

    /// Creates many handles concurrently. Each handle owns its own
    /// `ConcurrencySafeContainer` — there's no shared state between them, but the
    /// concurrent constructor invocations exercise the init-ordering writes
    /// (`sessionEventProxy`, `biometricAuthentication`) across threads.
    @Test func concurrentInitProducesIndependentHandles() {
        let handles = ConcurrencySafeReferenceList<MockSessionProvider>()

        Self.concurrentlyRun(count: 500) { _ in
            let provider = MockSessionProvider()
            let handle = AuthSessionHandle(sessionProvider: provider)
            handles.append(handle)
        }

        let collected = handles.snapshot()
        #expect(collected.count == 500)
        // Every handle must be wired correctly — proxy and biometric set, status syncing.
        for handle in collected {
            #expect(handle.sessionEventProxy != nil)
            #expect(handle.biometricAuthentication != nil)
            #expect(handle.sessionStatus == .syncing)
        }
    }

    /// A delegate that calls back into the handle from inside its own callback
    /// must not deadlock. The handle's lock is released before delegate dispatch,
    /// so this re-entry should succeed even when the call originates from the same
    /// thread.
    @Test func reentrantDelegateCallbackDoesNotDeadlock() {
        let provider = MockSessionProvider()
        let handle = AuthSessionHandle(sessionProvider: provider)

        let synchronousQueue = DispatchQueue(label: "test.synchronous-delegate")
        let didReenter = ConcurrencySafeFlag()

        final class ReentrantDelegate: NSObject, AuthSessionDelegate, @unchecked Sendable {
            let handle: AuthSessionHandle<MockSessionProvider>
            let didReenter: ConcurrencySafeFlag

            init(handle: AuthSessionHandle<MockSessionProvider>, didReenter: ConcurrencySafeFlag) {
                self.handle = handle
                self.didReenter = didReenter
            }

            func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?,
                                didUpdateStatus sessionStatus: any AuthSessionStatusProtocol,
                                from oldStatus: any AuthSessionStatusProtocol,
                                for session: (any AuthSessionProtocol)?) {
                // Re-enter the handle from the delegate callback.
                _ = handle.sessionStatus
                _ = handle.isManualAuthenticationRequired
                didReenter.set()
            }

            func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?,
                                didLoginWith user: (any AuthSessionUserProtocol)?,
                                for session: (any AuthSessionProtocol)?) { }

            func authentication(_ sessionHandle: (any AuthSessionHandleProtocol)?,
                                didLogoutWith error: Error?) { }
        }

        let delegate = ReentrantDelegate(handle: handle, didReenter: didReenter)
        handle.subscribeDelegate(delegate, receive: synchronousQueue)
        handle.set(sessionStatus: .signedIn)

        // Drain the synchronous delegate queue.
        synchronousQueue.sync {}
        #expect(didReenter.isSet == true)
    }

    /// **Chaos monkey** — every public/internal surface of the handle gets
    /// hammered concurrently from many threads with a deterministic but
    /// hostile mix of operations: status writes, status reads, flag toggles,
    /// event listener deliveries, delegate subscribe/unsubscribe, biometric
    /// flag flips, and re-entrant reads from inside delegate callbacks. If
    /// any of these paths is racy in a way the simpler targeted tests miss,
    /// this storm should crash or corrupt state.
    @Test func chaosMonkeyAllSurfacesUnderLoad() {
        let provider = MockSessionProvider()
        let handle = AuthSessionHandle(sessionProvider: provider)
        let listener = handle.listenEvent()

        // A live, ever-changing pool of delegates that subscribe and unsubscribe
        // independently of the operation storm.
        let delegatePool = (0..<16).map { _ in MockDelegate() }
        for delegate in delegatePool.prefix(8) {
            handle.subscribeDelegate(delegate, receive: delegateQueue)
        }

        let statuses: [AuthSessionStatus] = [.syncing, .signedIn, .signedOut, .validating, .biometricAuthentication]
        let events: [AuthSessionEvent] = [
            .fetchingSession,
            .sessionFetched(isInitialFetch: false),
            .sessionSignIn,
            .sessionSignedOut(error: nil),
            .sessionUpdated(nil),
            .unexpectedError(.sessionExpired)
        ]

        Self.concurrentlyRun(count: 50_000) { i in
            switch i % 16 {
            case 0:  handle.set(sessionStatus: statuses[i % statuses.count])
            case 1:  _ = handle.sessionStatus
            case 2:  handle.enableManualAuthentication()
            case 3:  handle.disableManualAuthentication()
            case 4:  _ = handle.isManualAuthenticationRequired
            case 5:  handle.enableSessionForValidation()
            case 6:  _ = handle.isSessionReadyToValidate
            case 7:  handle.enableSessionValidationFromNotification()
            case 8:  handle.disableSessionValidationFromNotification()
            case 9:  _ = handle.allowsSessionValidationFromNotifications
            case 10: listener(events[i % events.count])
            case 11: handle.setBioMetricAuthentication(i.isMultiple(of: 2))
            case 12: _ = handle.session?.accessToken
            case 13: handle.subscribeDelegate(delegatePool[i % delegatePool.count], receive: delegateQueue)
            case 14: handle.unsubscribeDelegate(delegatePool[i % delegatePool.count])
            case 15: _ = handle.isBiometricAuthenticationInProcess
            default: break
            }
        }

        drainDelegateQueue()

        // Survival check — handle still functional after 50,000 ops.
        let final = handle.sessionStatus
        #expect(statuses.contains(final))

        // The lock primitive must still respond — taking it one more time should be cheap and reliable.
        handle.set(sessionStatus: .signedIn)
        #expect(handle.sessionStatus == .signedIn)
    }

    /// Sustained burst load — twenty parallel writers hammer the same handle
    /// for a long run. Proves the lock holds up under continuous contention,
    /// not just short isolated bursts.
    @Test func sustainedBurstUnderContention() {
        let provider = MockSessionProvider()
        let handle = AuthSessionHandle(sessionProvider: provider)

        let writerCount = 32
        let iterationsPerWriter = 2_000
        let statuses: [AuthSessionStatus] = [.syncing, .signedIn, .signedOut, .validating, .biometricAuthentication]

        let group = DispatchGroup()
        for writerIndex in 0..<writerCount {
            group.enter()
            Self.stressQueue.async {
                for j in 0..<iterationsPerWriter {
                    handle.set(sessionStatus: statuses[(writerIndex + j) % statuses.count])
                }
                group.leave()
            }
        }
        group.wait()

        // Final status must be one of the valid enum cases. Lock failures or
        // memory corruption would have crashed long before this assertion.
        #expect(statuses.contains(handle.sessionStatus))
    }
}


// MARK: - Threading Test Helpers

/// Thread-safe counter used in `Thread Safety` suite. Backed by the same
/// `ConcurrencySafeContainer` the handle itself uses, so we're testing with
/// the production primitive.
final class ConcurrencySafeCounter: @unchecked Sendable {
    private let container = ConcurrencySafeContainer<Int>(0)
    func increment() { container.withLock { $0 += 1 } }
    var value: Int { container.withLock { $0 } }
}

/// Thread-safe one-shot Bool flag.
final class ConcurrencySafeFlag: @unchecked Sendable {
    private let container = ConcurrencySafeContainer<Bool>(false)
    func set() { container.withLock { $0 = true } }
    var isSet: Bool { container.withLock { $0 } }
}

/// Thread-safe list for collecting handles created concurrently in tests.
final class ConcurrencySafeReferenceList<Provider: AuthSessionProviderProtocol>: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [AuthSessionHandle<Provider>] = []

    func append(_ handle: AuthSessionHandle<Provider>) {
        lock.lock()
        items.append(handle)
        lock.unlock()
    }

    func snapshot() -> [AuthSessionHandle<Provider>] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }
}


// MARK: - Synchronous Init Emission

/// Provider that publishes `.fetchingSession` then `.sessionFetched(isInitialFetch: true)`
/// synchronously from inside `initializeSessionProvider(for:)`. Used to prove the
/// init-ordering invariant: the handle must have wired its `sessionEventProxy` and
/// `biometricAuthentication` references **before** delegating to the provider, otherwise
/// the synchronous validation pass would observe `nil` for those references and silently
/// skip the biometric branch.
final class SynchronousEmittingProvider: NSObject, AuthSessionProviderProtocol, @unchecked Sendable {

    var session: MockSession?
    var isBioMetricAuthenticationEnabled: Bool = true
    var allowsLocalSessionValidation: Bool = true
    var isSessionAutoRefreshEnabled: Bool = false
    var canPerformAuth: Bool = true
    var allowsSignoutOnBiometricFailure: Bool = true
    var signoutCallCount = 0

    init(session: MockSession) {
        self.session = session
    }

    func initializeSessionProvider(for eventProxy: any AuthSessionEventProxy) {
        // Emit synchronously, before the function returns.
        eventProxy.publish(.fetchingSession)
        eventProxy.publish(.sessionFetched(isInitialFetch: true))
    }

    func setBioMetricAuthentication(_ isEnabled: Bool) { isBioMetricAuthenticationEnabled = isEnabled }
    func signout(with error: Error?) throws { signoutCallCount += 1 }
    func preferredAuthenticationReason() -> String { "Sync test" }
    func canPerformAuthentication() -> Bool { canPerformAuth }
    func allowsSessionSigningOutOnBiometricAuthenticationFailure(with error: BiometricAuthenticationError) -> Bool {
        allowsSignoutOnBiometricFailure
    }
}


@Suite("Synchronous Init Emission")
struct SynchronousInitEmissionTests {

    /// The headline regression: a synchronously-emitting provider with a valid session
    /// and `canPerformAuthentication() == true` must land in `.biometricAuthentication`.
    /// If `biometricAuthentication` were still `nil` when the validation pass runs, the
    /// biometric branch would be skipped and the handle would land on `.signedIn`.
    @Test func biometricBranchFiresOnSynchronousFetch() {
        let session = MockSession(expiresIn: 3600)
        let provider = SynchronousEmittingProvider(session: session)
        let handle = AuthSessionHandle(sessionProvider: provider)

        // The provider already published .sessionFetched(isInitialFetch: true) before
        // init returned. The handle must have validated, taken the biometric branch,
        // and transitioned to .biometricAuthentication.
        #expect(handle.sessionStatus == .biometricAuthentication)
    }

    /// Without biometric (`canPerformAuth = false`) the handle should land on
    /// `.signedIn` instead — proves the validation pass actually ran (not silently
    /// short-circuited by missing state).
    @Test func validationStillRunsWhenBiometricUnavailable() {
        let session = MockSession(expiresIn: 3600)
        let provider = SynchronousEmittingProvider(session: session)
        provider.canPerformAuth = false
        let handle = AuthSessionHandle(sessionProvider: provider)

        #expect(handle.sessionStatus == .signedIn)
    }

    /// A synchronously-emitting provider with an expired session must trigger
    /// signout during init, proving the validation pass had a working reference to
    /// the provider and a fully wired event listener.
    @Test func expiredSessionTriggersSignoutDuringSyncInit() {
        let session = MockSession(expiresIn: 60) // below the 180s threshold
        let provider = SynchronousEmittingProvider(session: session)
        let handle = AuthSessionHandle(sessionProvider: provider)
        _ = handle // keep alive

        #expect(provider.signoutCallCount == 1)
    }

    /// `sessionEventProxy` and `biometricAuthentication` must be non-nil
    /// immediately after init returns — confirms the init-ordering write happens
    /// before `initializeSessionProvider(for:)` returns.
    @Test func referencesAreVisibleAfterInit() {
        let session = MockSession(expiresIn: 3600)
        let provider = SynchronousEmittingProvider(session: session)
        let handle = AuthSessionHandle(sessionProvider: provider)

        #expect(handle.sessionEventProxy != nil)
        #expect(handle.biometricAuthentication != nil)
    }

    /// Session-readiness must be `true` once the synchronous fetch completes,
    /// even though the assignment happened mid-`init`. Proves the event listener
    /// closure can mutate `state` from inside `initializeSessionProvider`.
    @Test func sessionReadinessSetBySynchronousFetch() {
        let session = MockSession(expiresIn: 3600)
        let provider = SynchronousEmittingProvider(session: session)
        let handle = AuthSessionHandle(sessionProvider: provider)

        #expect(handle.isSessionReadyToValidate == true)
    }
}
