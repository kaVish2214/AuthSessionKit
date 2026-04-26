//
//  Handle+ProviderEventListen.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import Foundation
import AuthSessionInterface


// MARK: - Event Handling

extension AuthSessionHandle {

    /// Returns a weak-capturing closure that routes session events to the appropriate
    /// status transitions and validation logic.
    ///
    /// Passed to ``SessionHandleEventProxy`` at init time so the proxy can forward
    /// provider events without the handle conforming to any external protocol.
    func listenEvent() -> @Sendable (AuthSessionEvent) -> Void {
        return { [weak self] event in
            guard let self else {
                return
            }
            switch event {
            case .fetchingSession:
                self.set(sessionStatus: .syncing)

            case .sessionFetched(let isInitialFetch):
                // Mark session ready so `didBecomeActive` validation can proceed.
                self.enableSessionForValidation()
                if isInitialFetch {
                    // First fetch at launch — run full local validation and biometric flow.
                    self.validateLocalSessionOrAuthenticateIfNeeded()
                } else {
                    // Subsequent fetches (e.g. token refresh) — skip biometric, just check expiry.
                    self.handleSessionStatusOnceFetched()
                }
                // Notify delegates that the fetch completed.
                self.invoke { [weak self] delegate in
                    delegate?.session(self?.session, sessionFetchDidComplete: isInitialFetch)
                }

            case .sessionFetchFailed(let error):
                // Even on failure, unlock validation so the handle doesn't stay stuck in `.syncing`.
                self.enableSessionForValidation()
                self.handleSessionStatusOnceFetched()
                self.invoke { [weak self] delegate in
                    delegate?.session(self?.session, didFailWith: .sessionFetchFailed(error: error))
                }

            case .sessionSignIn:
                self.set(sessionStatus: .signedIn)
                self.invoke { [weak self] delegate in
                    delegate?.session(self?.session, didLogin: self?.session?.user)
                }

            case .sessionSignedOut(let error):
                self.set(sessionStatus: .signedOut)
                self.invoke { [weak self] delegate in
                    delegate?.session(self?.session, didLogoutWith: error)
                }

            case .sessionUpdated(let session):
                // Session data changed (e.g. user profile update) — no status transition needed.
                self.invoke { delegate in
                    delegate?.session(session, didUpdate: session?.user)
                }

            case .unexpectedError(let error):
                self.invoke { [weak self] delegate in
                    delegate?.session(self?.session, didFailWith: error)
                }
            }
        }
    }
}
