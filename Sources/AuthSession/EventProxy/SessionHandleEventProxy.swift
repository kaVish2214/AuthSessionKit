// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import AuthSessionInterface
import BiometricAuthInterface


/// Bridges session provider events and biometric callbacks to the session handle
/// without exposing the handle to external protocols.
///
/// The provider calls ``publish(_:for:)`` to deliver session events, and
/// ``BiometricAuthManager`` calls the ``BiometricAuthenticationDelegator`` methods
/// for authentication results — both are forwarded to the handle via closures
/// and the ``SessionBiometricEventProxy``.
final class SessionHandleEventProxy: AuthSessionEventProxy {
    
    /// The closure that forwards session events to the handle.
    private let eventListening: @Sendable (AuthSessionEvent) -> Void

    /// A weak reference to the handle for biometric result forwarding.
    private weak let biometricEventProxy: (any SessionBiometricEventProxy)?

    /// Init with biometricEventProxy
    required init(eventListening: @escaping @Sendable (AuthSessionEvent) -> Void, biometricEventProxy: any SessionBiometricEventProxy) {
        self.eventListening = eventListening
        self.biometricEventProxy = biometricEventProxy
    }
    
    /// init with only eventListening
    init(eventListening: @escaping @Sendable (AuthSessionInterface.AuthSessionEvent) -> Void) {
        self.biometricEventProxy = nil
        self.eventListening = eventListening
    }
    
    /// Forwards a session event to the handle's event listener closure.
    func publish(_ event: AuthSessionEvent, for sessionProvider: (any AuthSessionProviderProtocol)?) {
        eventListening(event)
    }
}

// MARK: - BiometricAuthenticationDelegator

extension SessionHandleEventProxy: BiometricAuthenticationDelegator {

    /// Called when biometric authentication succeeds — transitions to `.signedIn`.
    func authenticated() {
        biometricEventProxy?.set(sessionStatus: .signedIn)
    }

    /// Called when biometric authentication fails — forwards to the handle which
    /// consults the provider's policy to decide between sign-out or staying signed in.
    func authenticationFailed(with error: BiometricAuthenticationError) {
        biometricEventProxy?.biometricAuthenticationFailure(with: error)
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
