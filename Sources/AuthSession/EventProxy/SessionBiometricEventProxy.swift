// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AuthSessionInterface
import BiometricAuthInterface

/// A type that handles biometric authentication outcomes on behalf of the session handle.
///
/// ``SessionHandleEventProxy`` holds a weak reference to a conformer and forwards
/// biometric success/failure callbacks through it, keeping the handle decoupled
/// from ``BiometricAuthenticationDelegator``.
protocol SessionBiometricEventProxy: AnyObject, Sendable {

    /// The event proxy used to route errors back to the session event system.
    var sessionEventProxy: (any AuthSessionEventProxy)? { get }

    /// Transitions the session to the given status (e.g., `.signedIn` on biometric success).
    func set(sessionStatus status: AuthSessionStatus)

    /// Handles a biometric authentication failure, delegating the sign-out
    /// decision to the session provider.
    func biometricAuthenticationFailure(with error: BiometricAuthenticationError)
    
    /// Notifies the handle that a biometric prompt is about to appear, so it
    /// can suppress notification-driven validation during the system alert.
    func biometricAuthenticationBeingAuthenticated()
}
