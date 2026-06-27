// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import AuthSessionInterface
import BiometricAuthInterface


// MARK: - SessionBiometricEventProxy

extension AuthSessionHandle: SessionBiometricEventProxy {
    
    /// Handles a biometric authentication failure by consulting the provider's policy.
    ///
    /// If the provider's ``AuthSessionProviderProtocol/allowsSessionSigningOutOnBiometricAuthenticationFailure(with:)``
    /// returns `true`, the user is signed out. Otherwise, manual authentication is
    /// enabled (blocking automatic `didBecomeActive` validation), the session stays
    /// at `.signedIn`, and the failure is broadcast as an `.unexpectedError` so
    /// delegates can present a retry or fallback UI.
    func biometricAuthenticationFailure(with error: BiometricAuthenticationError) {
        let shouldSignOut: Bool = sessionProvider.allowsSessionSigningOutOnBiometricAuthenticationFailure(with: error)
        if shouldSignOut {
            do {
                try sessionProvider.signout(with: error)
            } catch {
               sessionEventProxy?.publish(.unexpectedError(.signingOutFailure(error: error)))
            }
        }else {
            enableManualAuthentication()
            set(sessionStatus: .signedIn)
            sessionEventProxy?.publish(.unexpectedError(.biometricAuthFailure(error: error)))
        }
    }
    
    /// Called when the biometric prompt is about to be presented.
    ///
    /// Disables notification-based validation to prevent the `didBecomeActive`
    /// event (triggered by the system biometric alert) from starting a second
    /// authentication cycle. Also clears the manual authentication flag, since
    /// biometric is now actively handling re-authentication.
    func biometricAuthenticationBeingAuthenticated() {
        disableSessionValidationFromNotification()
        disableManualAuthentication()
    }
}
