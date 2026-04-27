//
//  AuthSessionHandle.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import Foundation
import AuthSessionInterface
import BiometricAuthInterface
import BiometricAuth
import MultiCastDelegate


/// Manages the lifecycle of an authentication session for a given provider.
///
/// `AuthSessionHandle` coordinates session fetching, local validation, biometric authentication,
/// and status transitions. It observes `didBecomeActiveNotification` to re-validate sessions
/// when the app returns to the foreground.
///
/// Event delivery from the provider and biometric callbacks are routed through
/// ``SessionHandleEventProxy``, keeping the handle decoupled from external protocols.
public final class AuthSessionHandle<AuthSessionProvider>: NSObject, AuthSessionHandleInterface, @unchecked Sendable where AuthSessionProvider: AuthSessionProviderInterface {

    // MARK: - Protocol Requirements

    /// The session provider responsible for fetching, refreshing, and signing out sessions.
    public let sessionProvider: AuthSessionProvider
    
    /// The multicast delegate subscription that manages ``AuthSessionDelegate`` observers.
    public let delegates: any DelegateSubscription = DelegateSubscriptionHandle()

    /// The current session from the provider, or `nil` if the user is not signed in.
    public var session: AuthSessionProvider.AuthSession? {
        return sessionProvider.session
    }

    /// Whether a biometric authentication prompt is currently being presented.
    public var isBiometricAuthenticationInProcess: Bool {
        return biometricAuthentication?.isAuthRequestInProcess == true
    }

    /// When `true`, automatic session validation on `didBecomeActive` is skipped
    /// and the caller must authenticate manually.
    private(set) public var isManualAuthenticationRequired: Bool = false

    // MARK: - Internal State

    /// The current session status, observed by the UI layer to drive screen transitions.
    private(set) public var sessionStatus: AuthSessionStatus = .syncing {
        didSet {
            invokeStatusChangeDelegates(oldValue: oldValue, newValue: sessionStatus)
        }
    }

    /// The biometric authentication manager, or `nil` if biometrics are unavailable.
    private(set) var biometricAuthentication: (any BiometricAuthentication)?

    /// Guards ``validateLocalSessionOrAuthenticateIfNeeded()`` from running before
    /// the first session fetch completes, preventing a premature `.signedOut` when
    /// `didBecomeActive` fires at launch.
    ///
    /// Set to `true` by ``enableSessionForValidation()`` once the provider delivers
    /// a `.sessionFetched` or `.sessionFetchFailed` event.
    private(set) var isSessionReadyToValidate: Bool = false

    /// Gates the `didBecomeActive` notification handler so it skips validation
    /// when it shouldn't run.
    ///
    /// Starts `false` — on the first `didBecomeActive`, the flag is set to `true`
    /// without triggering validation, deferring to the provider's initial fetch.
    /// Also set back to `false` by ``disableSessionValidationFromNotification()``
    /// when a biometric prompt appears, preventing the system's foreground event
    /// from starting a redundant validation cycle.
    private(set) var allowsSessionValidationFromNotifications: Bool = false

    /// The observer token returned by `NotificationCenter`, stored for removal in `deinit`.
    var notificationObserver: (any NSObjectProtocol)?
    
    /// The event proxy that forwards provider and biometric events to this handle.
    private(set) var sessionEventProxy: (any AuthSessionEventProxy)?

    // MARK: - Lifecycle

    /// Creates a session handle for the given provider.
    ///
    /// Sets up a ``SessionHandleEventProxy`` that routes provider events and biometric
    /// callbacks back to this handle, initializes the provider, and begins listening
    /// for `didBecomeActiveNotification`.
    /// - Parameter sessionProvider: The provider that manages the underlying session.
    required public init(sessionProvider: AuthSessionProvider) {
        self.sessionProvider = sessionProvider
        super.init()
        
        let eventProxy: any AuthSessionEventProxy & BiometricAuthenticationDelegator = SessionHandleEventProxy.init(eventListening: listenEvent(), biometricEventProxy: self)
        self.biometricAuthentication = BiometricAuthManager(requestor: sessionProvider, delegator: eventProxy)
        sessionProvider.initializeSessionProvider(for: eventProxy)
        self.sessionEventProxy = eventProxy
        startListeningApplicationNotifications()
    }

    /// Removes the `didBecomeActiveNotification` observer to prevent a retain cycle.
    deinit {
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
    }

    // MARK: - Manual Authentication

    /// Switches to manual authentication mode, disabling automatic validation on `didBecomeActive`.
    func enableManualAuthentication() {
        guard !isManualAuthenticationRequired else { return }
        isManualAuthenticationRequired = true
    }

    /// Restores automatic session validation on `didBecomeActive`.
    func disableManualAuthentication() {
        guard isManualAuthenticationRequired else { return }
        isManualAuthenticationRequired = false
    }

    // MARK: - Session Readiness

    /// Marks the session as ready for local validation after the initial fetch completes.
    ///
    /// Called from the event listener when the provider delivers `.sessionFetched` or
    /// `.sessionFetchFailed`, unlocking ``validateLocalSessionOrAuthenticateIfNeeded()``.
    func enableSessionForValidation() {
        guard !isSessionReadyToValidate else { return }
        isSessionReadyToValidate = true
    }

    /// Marks the notification handler as ready to trigger validation.
    ///
    /// Called once during the first `didBecomeActive` notification. Until this flag
    /// is set, notification callbacks skip validation to avoid racing with the
    /// provider's initial fetch.
    func enableSessionValidationFromNotification() {
        guard !allowsSessionValidationFromNotifications else { return }
        allowsSessionValidationFromNotifications = true
    }
    
    /// Temporarily prevents the `didBecomeActive` notification handler from
    /// triggering session validation.
    ///
    /// Called when a biometric prompt is about to appear, because the system
    /// alert backgrounds and re-foregrounds the app — which would fire
    /// `didBecomeActive` and start a second validation/biometric cycle.
    func disableSessionValidationFromNotification() {
        guard allowsSessionValidationFromNotifications else { return }
        allowsSessionValidationFromNotifications = false
    }

    // MARK: - Status

    /// Transitions to the given session status, ignoring no-op transitions.
    /// - Parameter status: The new status to apply.
    func set(sessionStatus status: AuthSessionStatus) {
        guard status != self.sessionStatus else { return }
        self.sessionStatus = status
    }
}

// MARK: - Delegate Invocation

extension AuthSessionHandle {

    /// Notifies all subscribed delegates when the session status changes.
    func invokeStatusChangeDelegates(oldValue: SessionStatus, newValue: SessionStatus) {
        guard oldValue != newValue else {
            return
        }
        invoke { [weak self]delegate in
            delegate?.session(self?.session, didUpdate: newValue, where: oldValue)
        }
    }
}
