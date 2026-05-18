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
    /// Skips local validation if the provider handles auto-refresh. Otherwise,
    /// checks expiry and signs out if the session is stale.
    ///
    /// `.signedIn` transitions are skipped while a biometric prompt is actively
    /// running, so a concurrent fetch cannot clobber the in-progress
    /// `.biometricAuthentication` status. Expired-session signouts are NOT
    /// guarded — a dead session must take priority over biometric.
    ///
    /// - Parameter shouldForceSignOut: When `true` and the session is `nil`, calls
    ///   `provider.signout(with:)` so the provider broadcasts a signout event.
    ///   When `false`, only sets the status to `.signedOut` without notifying
    ///   the provider.
    func handleSessionStatusOnceFetched(shouldForceSignOut: Bool) {
        guard let session else {
            if shouldForceSignOut {
                do {
                    try sessionProvider.signout(with: AuthSessionError.sessionExpired)
                } catch {
                    self.sessionEventProxy?.execute(.unexpectedError(.signingOutFailure(error: error)))
                }
            }else {
                set(sessionStatus: .signedOut)
            }
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
