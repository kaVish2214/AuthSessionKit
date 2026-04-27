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

    /// Forwards a biometric-triggered sign-out to the session provider.
    /// - Parameter error: The error that caused the sign-out, or `nil` for a voluntary sign-out.
    /// - Throws: Rethrows any error from the provider's `signout(with:)`.
    func biometricAuthProxyRequestSignout(with error: (any Error)?) throws {
        try sessionProvider.signout(with: error)
    }
    
    /// Called when the biometric prompt is about to be presented.
    ///
    /// Disables notification-based validation to prevent the `didBecomeActive`
    /// event (triggered by the system biometric alert) from starting a second
    /// authentication cycle.
    func biometricAuthenticationBeingAuthenticated() {
        disableSessionValidationFromNotification()
    }
}
