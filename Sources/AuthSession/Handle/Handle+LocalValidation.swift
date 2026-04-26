//
//  Handle+LocalValidation.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import Foundation
import AuthSessionInterface


// MARK: - Local Validation

extension AuthSessionHandle {

    /// Validates the current session locally and triggers biometric authentication if needed.
    ///
    /// Called on `didBecomeActive`. Guards against running before the initial fetch,
    /// during an active biometric prompt, or when manual authentication is required.
    func validateLocalSessionOrAuthenticateIfNeeded() {
        // Wait until the first session fetch has completed to avoid a false `.signedOut`.
        guard isSessionReadyToValidate else {
            return
        }
        guard let session else {
            set(sessionStatus: .signedOut)
            return
        }
        // Don't interrupt an in-flight biometric prompt.
        guard !isBiometricAuthenticationInProcess else {
            return
        }

        // Branch A: Provider supports local expiry checks.
        if sessionProvider.allowsLocalSessionValidation {
            if sessionStatus.allowsLocalValidation {
                set(sessionStatus: .validating)

                // Session expires within 3 minutes — treat as expired and sign out.
                if session.expiresIn <= 180 {
                    do {
                        try sessionProvider.signout(with: AuthSessionError.sessionExpired)
                    } catch {
                        self.sessionEventProxy?.execute(.unexpectedError(.signingOutFailure(error: error)))
                    }
                // Session is still valid — request biometric re-authentication if available.
                } else if sessionProvider.canPerformAuthentication(), let biometricAuth = biometricAuthentication {
                    set(sessionStatus: .biometricAuthentication)
                    biometricAuth.authenticate(Date())
                // No biometric available — session is valid, proceed as signed in.
                } else {
                    set(sessionStatus: .signedIn)
                }
            }

        // Branch B: No local validation, but biometric is available — authenticate only.
        } else if sessionProvider.canPerformAuthentication() {
            if sessionStatus.allowsBiometricAuthentication, let biometricAuth = biometricAuthentication {
                set(sessionStatus: .biometricAuthentication)
                biometricAuth.authenticate(Date())
            } else {
                set(sessionStatus: .signedIn)
            }

        // Branch C: No validation, no biometric — if still syncing, transition to signed in.
        } else if sessionStatus == .syncing {
            set(sessionStatus: .signedIn)
        }
    }
}
