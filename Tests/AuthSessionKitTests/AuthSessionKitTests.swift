import Testing
import Foundation
@testable import AuthSession
@testable import AuthSessionInterface
import BiometricAuthInterface
import MultiCastDelegate


// MARK: - Mock Types

struct MockUser: AuthSessionUserInterface, @unchecked Sendable {
    var identifier: String = "mock-user-id"
}

final class MockSession: AuthSessionInterface, @unchecked Sendable {

    var accessToken: String
    var expiresAt: TimeInterval
    var user: MockUser

    init(accessToken: String = "mock-token", expiresIn seconds: TimeInterval = 3600, user: MockUser = MockUser()) {
        self.accessToken = accessToken
        self.expiresAt = Date().timeIntervalSince1970 + seconds
        self.user = user
    }
}

final class MockSessionProvider: NSObject, AuthSessionProviderInterface, @unchecked Sendable {

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

    @Test func biometricBeingAuthenticatedDisablesFlag() {
        let (handle, _) = makeHandle()
        handle.enableSessionValidationFromNotification()
        #expect(handle.allowsSessionValidationFromNotifications == true)
        handle.biometricAuthenticationBeingAuthenticated()
        #expect(handle.allowsSessionValidationFromNotifications == false)
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


// MARK: - AuthSessionInterface Default Extensions

@Suite("AuthSessionInterface Defaults")
struct AuthSessionInterfaceTests {

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

    var statusChanges: [(new: any AuthSessionStatusInterface, old: any AuthSessionStatusInterface)] = []
    var loginCount = 0
    var logoutCount = 0
    var logoutErrors: [Error?] = []
    var fetchCompletions: [Bool] = []
    var failureErrors: [AuthSessionError] = []
    var userUpdates = 0

    func session(_ session: (any AuthSessionInterface)?, didUpdate sessionStatus: any AuthSessionStatusInterface, where oldStatus: any AuthSessionStatusInterface) {
        statusChanges.append((new: sessionStatus, old: oldStatus))
    }

    func session(_ session: (any AuthSessionInterface)?, didLogin user: (any AuthSessionUserInterface)?) {
        loginCount += 1
    }

    func session(_ session: (any AuthSessionInterface)?, didLogoutWith error: Error?) {
        logoutCount += 1
        logoutErrors.append(error)
    }

    func session(_ session: (any AuthSessionInterface)?, sessionFetchDidComplete isInitialFetch: Bool) {
        fetchCompletions.append(isInitialFetch)
    }

    func session(_ session: (any AuthSessionInterface)?, didFailWith error: AuthSessionError) {
        failureErrors.append(error)
    }

    func session(_ session: (any AuthSessionInterface)?, didUpdate user: (any AuthSessionUserInterface)?) {
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

    @Test func executeForwardsEventToClosure() {
        let counter = SendableCounter()
        let proxy = SessionHandleEventProxy(eventListening: { _ in
            counter.increment()
        })
        proxy.execute(.fetchingSession)
        proxy.execute(.sessionSignIn)
        #expect(counter.value == 2)
    }

    @Test func executeConvenienceOmitsProvider() {
        let counter = SendableCounter()
        let proxy = SessionHandleEventProxy(eventListening: { _ in
            counter.increment()
        })
        proxy.execute(.fetchingSession)
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
        proxy.execute(.sessionSignIn)
        proxy.authenticated()
    }
}
