//
//  Handle+Biometric.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

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
               sessionEventProxy?.execute(.unexpectedError(.signingOutFailure(error: error)))
            }
        }else {
            enableManualAuthentication()
            set(sessionStatus: .signedIn)
            sessionEventProxy?.execute(.unexpectedError(.biometricAuthFailure(error: error)))
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
