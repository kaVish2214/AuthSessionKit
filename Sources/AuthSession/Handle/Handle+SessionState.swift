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

    /// Evaluates the session after a non-initial fetch and transitions to the appropriate status.
    ///
    /// Skips local validation if the provider handles auto-refresh. Otherwise, checks expiry
    /// and signs out if the session is stale.
    func handleSessionStatusOnceFetched() {
        guard let session else {
            set(sessionStatus: .signedOut)
            return
        }
        // Provider manages its own refresh cycle — trust the session and skip local expiry checks.
        if !sessionProvider.allowsLocalSessionValidation && sessionProvider.isSessionAutoRefreshEnabled {
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
            set(sessionStatus: .signedIn)
        }
    }
}
