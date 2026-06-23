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
import SwiftConcurrency


/// Manages the lifecycle of an authentication session for a given provider.
///
/// `AuthSessionHandle` coordinates session fetching, local validation, biometric authentication,
/// and status transitions. It observes `didBecomeActiveNotification` to re-validate sessions
/// when the app returns to the foreground.
///
/// Event delivery from the provider and biometric callbacks are routed through
/// ``SessionHandleEventProxy``, keeping the handle decoupled from external protocols.
///
/// ## Thread Safety
///
/// Mutable members fall into two categories, each handled differently:
///
/// - **Continuously-mutated scalars** — `sessionStatus`,
///   `isManualAuthenticationRequired`, `isSessionReadyToValidate`,
///   `allowsSessionValidationFromNotifications`. These live inside a private
///   `Sendable` `State` struct held by a
///   ``ConcurrencyContainerProtocol`` (from `UtilityKit`'s `SwiftConcurrency`
///   product). Every read and write goes through `withLock`, so the compiler
///   enforces `Sendable` on every value flowing in or out.
/// - **Write-once-during-init references** — `sessionEventProxy`,
///   `biometricAuthentication`, `notificationObserver`. Declared
///   `private(set) nonisolated(unsafe) var` because they are assigned exactly
///   once during `init` (before any external thread can observe `self`) and
///   only read afterwards. The lock would be pure overhead — the invariant is
///   *"no writes after init"*, enforced by code review rather than runtime.
///
/// The backing lock is OS-adaptive (`Mutex` on iOS 18+ / macOS 15+,
/// `OSAllocatedUnfairLock` on iOS 16+ / macOS 13+, `NSLock` below). Critical
/// sections never wrap external calls — delegate dispatch, provider sign-out,
/// and biometric authentication all happen *outside* the lock — so there's no
/// re-entrancy or deadlock risk.
///
/// As a result, every public and internal method on `AuthSessionHandle` is
/// safe to call from any thread, actor, or queue. The class is genuinely
/// `Sendable` (no `@unchecked`).
///
/// ## Init ordering invariant
///
/// `sessionEventProxy` and `biometricAuthentication` are assigned **before**
/// `sessionProvider.initializeSessionProvider(for:)` is called. This ensures
/// that a provider which synchronously publishes events during initialization
/// (e.g., emitting `.fetchingSession` and `.sessionFetched(isInitialFetch: true)`
/// inline) sees a fully-wired handle when the event listener fires — the
/// biometric branch in ``Handle+LocalValidation`` cannot be silently skipped
/// due to a `nil` biometric manager, and signout-failure error publishes
/// reach the proxy instead of being dropped.
public final class AuthSessionHandle<AuthSessionProvider>: AuthSessionHandleProtocol where AuthSessionProvider: AuthSessionProviderProtocol {

    /// The continuously-mutated state of the handle, held inside ``state``
    /// behind a ``ConcurrencyContainerProtocol`` lock.
    ///
    /// Every mutable scalar lives here — anything that can change after init,
    /// across the lifetime of the handle, gets a slot in this struct. The
    /// struct itself is `Sendable`, so all reads and writes go through
    /// `withLock`, with compiler-enforced `Sendable` checks on the values
    /// crossing the boundary.
    private struct State: Sendable {

        /// Backing storage for ``AuthSessionHandle/isManualAuthenticationRequired``.
        var isManualAuthenticationRequired: Bool = false

        /// Backing storage for ``AuthSessionHandle/sessionStatus``.
        var sessionStatus: AuthSessionStatus = .syncing

        /// Backing storage for ``AuthSessionHandle/isSessionReadyToValidate``.
        var isSessionReadyToValidate: Bool = false

        /// Backing storage for ``AuthSessionHandle/allowsSessionValidationFromNotifications``.
        var allowsSessionValidationFromNotifications: Bool = false
    }
    
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
    public var isManualAuthenticationRequired: Bool {
        state.withLock({ $0.isManualAuthenticationRequired })
    }

    // MARK: - Internal State

    /// The current session status, observed by the UI layer to drive screen transitions.
    public var sessionStatus: AuthSessionStatus {
        state.withLock{ $0.sessionStatus }
    }

    /// The biometric authentication manager, or `nil` if biometrics are unavailable.
    ///
    /// Declared `nonisolated(unsafe)` because it follows the **write-once-during-init**
    /// contract: assigned exactly once inside ``init(sessionProvider:)`` *before*
    /// `sessionProvider.initializeSessionProvider(for:)` is called, and never mutated
    /// again afterwards. Concurrent readers (event listeners, validation paths) always
    /// observe a fully-published value.
    private(set) nonisolated(unsafe) var biometricAuthentication: (any BiometricAuthentication)?

    /// Guards ``validateLocalSessionOrAuthenticateIfNeeded()`` from running before
    /// the first session fetch completes, preventing a premature `.signedOut` when
    /// `didBecomeActive` fires at launch.
    ///
    /// Set to `true` by ``enableSessionForValidation()`` once the provider delivers
    /// a `.sessionFetched` or `.sessionFetchFailed` event.
    var isSessionReadyToValidate: Bool {
        state.withLock{ $0.isSessionReadyToValidate }
    }

    /// Gates the `didBecomeActive` notification handler so it skips validation
    /// when it shouldn't run.
    ///
    /// Starts `false` — on the first `didBecomeActive`, the flag is set to `true`
    /// without triggering validation, deferring to the provider's initial fetch.
    /// Also set back to `false` by ``disableSessionValidationFromNotification()``
    /// when a biometric prompt appears, preventing the system's foreground event
    /// from starting a redundant validation cycle.
    var allowsSessionValidationFromNotifications: Bool {
        state.withLock{ $0.allowsSessionValidationFromNotifications }
    }

    /// The observer token returned by `NotificationCenter`, stored for removal in `deinit`.
    ///
    /// Declared `nonisolated(unsafe)` because it follows the **write-once-during-init**
    /// contract: assigned exactly once via ``setNotificationObserver(_:)`` from
    /// ``startListeningApplicationNotifications()`` (called inside ``init(sessionProvider:)``)
    /// and only read again from `deinit`, which by definition runs after all other
    /// references have been released.
    private(set) nonisolated(unsafe) var notificationObserver: (any NSObjectProtocol)?

    /// The event proxy that forwards provider and biometric events to this handle.
    ///
    /// Declared `nonisolated(unsafe)` because it follows the **write-once-during-init**
    /// contract: assigned exactly once inside ``init(sessionProvider:)`` *before*
    /// `sessionProvider.initializeSessionProvider(for:)` is called, and never mutated
    /// again afterwards. Synchronous provider emissions during init see the
    /// fully-published reference.
    private(set) nonisolated(unsafe) var sessionEventProxy: (any AuthSessionEventProxy)?

    /// The lock-protected box for continuously-mutated scalars (see ``State``).
    ///
    /// All reads and writes of the values in ``State`` go through this container's
    /// `withLock` entry point. The backing primitive is picked by
    /// ``ConcurrencySafeContainer`` based on OS version
    /// (`Mutex` → `OSAllocatedUnfairLock` → `NSLock`).
    private let state: any ConcurrencyContainerProtocol<State> = ConcurrencySafeContainer(State())
    

    // MARK: - Lifecycle

    /// Creates a session handle for the given provider.
    ///
    /// Sets up a ``SessionHandleEventProxy`` that routes provider events and biometric
    /// callbacks back to this handle, initializes the provider, and begins listening
    /// for `didBecomeActiveNotification`.
    /// - Parameter sessionProvider: The provider that manages the underlying session.
    required public init(sessionProvider: AuthSessionProvider) {
        self.sessionProvider = sessionProvider
        
        let eventProxy: any AuthSessionEventProxy & BiometricAuthenticationDelegator = SessionHandleEventProxy.init(eventListening: listenEvent(), biometricEventProxy: self)
        
        // Wire BEFORE the provider gets a chance to emit synchronously.
        self.sessionEventProxy = eventProxy
        self.biometricAuthentication = BiometricAuthManager(requestor: sessionProvider, delegator: eventProxy)
        
        sessionProvider.initializeSessionProvider(for: eventProxy)
        startListeningApplicationNotifications()
    }

    /// Removes the `didBecomeActiveNotification` observer to prevent a retain cycle.
    deinit {
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
    }

    // MARK: - Manual Authentication

    /// Switches to manual authentication mode, disabling automatic validation on
    /// `didBecomeActive`.
    ///
    /// Skipped when a biometric prompt is in progress or manual auth is already
    /// active. Cleared automatically by ``disableManualAuthentication()`` when the
    /// session exits the `.validating` state.
    func enableManualAuthentication() {
        guard !isManualAuthenticationRequired && !isBiometricAuthenticationInProcess else { return }
        state.withLock({
            $0.isManualAuthenticationRequired = true
        })
    }

    /// Restores automatic session validation on `didBecomeActive`.
    func disableManualAuthentication() {
        guard isManualAuthenticationRequired else { return }
        state.withLock({
            $0.isManualAuthenticationRequired = false
        })
    }
    
    /// Triggers session validation when manual authentication is required.
    ///
    /// Intended to be called from the UI after a biometric failure left the
    /// session in a "manual auth required" state. Guards on
    /// ``isManualAuthenticationRequired`` so it's safe to call unconditionally.
    public func requestManualAuthentication() {
        guard isManualAuthenticationRequired else {
            return
        }
        validateLocalSessionOrAuthenticateIfNeeded()
    }

    // MARK: - Session Readiness

    /// Marks the session as ready for local validation after the initial fetch completes.
    ///
    /// Called from the event listener when the provider delivers `.sessionFetched` or
    /// `.sessionFetchFailed`, unlocking ``validateLocalSessionOrAuthenticateIfNeeded()``.
    func enableSessionForValidation() {
        guard !isSessionReadyToValidate else { return }
        state.withLock({ $0.isSessionReadyToValidate = true })
    }

    /// Marks the notification handler as ready to trigger validation.
    ///
    /// Called from the `didBecomeActive` notification handler when the flag is
    /// currently `false`. Skipped when a biometric prompt is in progress
    /// (`isBiometricAuthenticationInProcess`), so the system's foreground event
    /// during the biometric alert cannot re-arm notification validation.
    func enableSessionValidationFromNotification() {
        guard !allowsSessionValidationFromNotifications && !isBiometricAuthenticationInProcess else { return }
        state.withLock{ $0.allowsSessionValidationFromNotifications = true }
    }
    
    /// Temporarily prevents the `didBecomeActive` notification handler from
    /// triggering session validation.
    ///
    /// Called when a biometric prompt is about to appear, because the system
    /// alert backgrounds and re-foregrounds the app — which would fire
    /// `didBecomeActive` and start a second validation/biometric cycle.
    func disableSessionValidationFromNotification() {
        guard allowsSessionValidationFromNotifications else { return }
        state.withLock{ $0.allowsSessionValidationFromNotifications = false }
    }

    // MARK: - Status

    /// Transitions to the given session status, ignoring no-op transitions.
    /// - Parameter status: The new status to apply.
    func set(sessionStatus status: AuthSessionStatus) {
        guard status != self.sessionStatus else { return }
        let oldValue = state.withLock({
            let old = $0.sessionStatus
            $0.sessionStatus = status
            return old
        })
        invokeStatusChangeDelegates(oldValue: oldValue, newValue: status)
    }
    
    // MARK: - Notification Observation

    /// Stores the `NotificationCenter` observer token returned by
    /// ``startListeningApplicationNotifications()``.
    ///
    /// Exposed as an internal write seam because ``notificationObserver`` uses
    /// `private(set)`, which restricts direct writes to the file scope. The
    /// `Handle+Notifications.swift` extension lives in a separate file, so it
    /// goes through this method instead. Called exactly once, during init.
    /// - Parameter observation: The opaque observer token to remove from
    ///   `NotificationCenter` in `deinit`.
    func setNotificationObserver(_ observation: NSObjectProtocol) {
        self.notificationObserver = observation
    }
}

// MARK: - Delegate Invocation

extension AuthSessionHandle {

    /// Notifies all subscribed delegates when the session status changes.
    ///
    /// Also clears ``isManualAuthenticationRequired`` when the session transitions
    /// out of `.validating` or into `.signedOut`, restoring automatic
    /// notification-based validation. The `.signedOut` clear prevents the flag
    /// from leaking across a signout when the transition didn't pass through
    /// `.validating` (e.g., external signout event, biometric failure with
    /// provider-allowed signout).
    func invokeStatusChangeDelegates(oldValue: SessionStatus, newValue: SessionStatus) {
        guard oldValue != newValue else {
            return
        }
        if oldValue.isValidating && !newValue.isValidating {
            disableManualAuthentication()
        }
        if newValue.isSignedOut && isManualAuthenticationRequired {
            disableManualAuthentication()
        }
        invoke { [weak self]delegate in
            delegate?.authentication(self, didUpdateStatus: newValue, from: oldValue, for: self?.session)
        }
    }
}
