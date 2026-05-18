//
//  Handle+SessionState.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import Foundation
import AuthSessionInterface


// MARK: - Post-Fetch Session State

extension AuthSessionHandle {

    /// Evaluates the session after a subsequent fetch (token refresh) or a fetch
    /// failure and transitions to the appropriate status.
    ///
    /// When there is no session, transitions directly to `.signedOut`. Otherwise,
    /// trusts the session if the provider handles auto-refresh; if local
    /// validation is in play, signs out an expired session and otherwise
    /// transitions to `.signedIn`.
    ///
    /// `.signedIn` transitions are skipped while a biometric prompt is actively
    /// running, so a concurrent fetch cannot clobber the in-progress
    /// `.biometricAuthentication` status. Expired-session signouts are NOT
    /// guarded — a dead session must take priority over biometric.
    func handleSessionStatusOnceFetched() {
        guard let session else {
            set(sessionStatus: .signedOut)
            return
        }
        
        // Provider manages its own refresh cycle — trust the session and skip local expiry checks.
        if !sessionProvider.allowsLocalSessionValidation && sessionProvider.isSessionAutoRefreshEnabled {
            // Drop the event if a biometric prompt is actively running — the user is
            // already signed in, and biometric completion will drive `.signedIn` itself.
            guard !(sessionStatus.isBiometricAuthentication && isBiometricAuthenticationInProcess) else {
                return
            }
            set(sessionStatus: .signedIn)
            return
        }
        // Session has expired — force sign out.
        if session.isSessionExpired {
            do {
                try sessionProvider.signout(with: AuthSessionError.sessionExpired)
            } catch {
                self.sessionEventProxy?.execute(.unexpectedError(.signingOutFailure(error: error)))
            }
        } else {
            // Drop the event if a biometric prompt is actively running — the user is
            // already signed in, and biometric completion will drive `.signedIn` itself.
            guard !(sessionStatus.isBiometricAuthentication && isBiometricAuthenticationInProcess) else {
                return
            }
            set(sessionStatus: .signedIn)
        }
    }
}
