//
//  SessionHandleEventProxy.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import Foundation
import AuthSessionInterface
import BiometricAuthInterface


/// Bridges session provider events and biometric callbacks to the session handle
/// without exposing the handle to external protocols.
///
/// The provider calls ``execute(_:for:)`` to deliver session events, and
/// ``BiometricAuthManager`` calls the ``BiometricAuthenticationDelegator`` methods
/// for authentication results — both are forwarded to the handle via closures
/// and the ``SessionBiometricEventProxy``.
final class SessionHandleEventProxy: NSObject, AuthSessionEventProxy, @unchecked Sendable {

    /// The closure that forwards session events to the handle.
    private let eventListening: @Sendable (AuthSessionEvent) -> Void

    /// A weak reference to the handle for biometric result forwarding.
    private weak var biometricEventProxy: (any SessionBiometricEventProxy)?

    init(eventListening: @escaping @Sendable (AuthSessionEvent) -> Void) {
        self.eventListening = eventListening
        super.init()
    }

    convenience init(eventListening: @escaping @Sendable (AuthSessionEvent) -> Void, biometricEventProxy: any SessionBiometricEventProxy) {
        self.init(eventListening: eventListening)
        self.biometricEventProxy = biometricEventProxy
    }

    /// Forwards a session event to the handle's event listener closure.
    func execute(_ event: AuthSessionEvent, for sessionProvider: (any AuthSessionProviderInterface)?) {
        eventListening(event)
    }
}

// MARK: - BiometricAuthenticationDelegator

extension SessionHandleEventProxy: BiometricAuthenticationDelegator {

    /// Called when biometric authentication succeeds — transitions to `.signedIn`.
    func authenticated() {
        biometricEventProxy?.set(sessionStatus: .signedIn)
    }

    /// Called when biometric authentication fails — requests sign-out through the handle.
    func authenticationFailed(with error: BiometricAuthenticationError) {
        do {
            try biometricEventProxy?.biometricAuthProxyRequestSignout(with: error)
        } catch {
            biometricEventProxy?.sessionEventProxy?.execute(.unexpectedError(.signingOutFailure(error: error)))
        }
    }

    /// Called when the biometric prompt presentation state changes.
    ///
    /// On the transition from idle to in-progress (`false` → `true`), notifies the
    /// handle to suppress notification-based validation so the system's foreground
    /// event doesn't trigger a second biometric cycle.
    func authenticationRequestInProcess(didChange from: Bool, to: Bool) {
        if to {
            biometricEventProxy?.biometricAuthenticationBeingAuthenticated()
        }
    }
}
