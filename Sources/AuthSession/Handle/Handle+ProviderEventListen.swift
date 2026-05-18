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
    ///
    /// `sessionSignIn` is ignored while a biometric prompt is actively running so a
    /// provider that fires `.sessionFetched` and `.sessionSignIn` in quick succession
    /// cannot clobber the in-progress `.biometricAuthentication` status. The user is
    /// already signed in when biometric runs, so the dropped event carries no new
    /// "first login" semantic — biometric completion drives the `.signedIn` transition.
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
                    delegate?.authentication(self, didCompleteFetchWith: self?.session, isInitialFetch: isInitialFetch)
                }

            case .sessionFetchFailed(let error):
                // Even on failure, unlock validation so the handle doesn't stay stuck in `.syncing`.
                self.enableSessionForValidation()
                self.handleSessionStatusOnceFetched()
                self.invoke { [weak self] delegate in
                    delegate?.authentication(self, didFailWith: .sessionFetchFailed(error: error), for: self?.session)
                }

            case .sessionSignIn:
                // Drop the event if a biometric prompt is actively running — the user is
                // already signed in, and biometric completion will drive `.signedIn` itself.
                guard !(sessionStatus.isBiometricAuthentication && isBiometricAuthenticationInProcess) else {
                    return
                }
                self.set(sessionStatus: .signedIn)
                self.invoke { [weak self] delegate in
                    delegate?.authentication(self, didLoginWith: self?.session?.user, for: self?.session)
                }

            case .sessionSignedOut(let error):
                self.set(sessionStatus: .signedOut)
                self.invoke { [weak self] delegate in
                    delegate?.authentication(self, didLogoutWith: error)
                }

            case .sessionUpdated(let session):
                // Session data changed (e.g. user profile update) — no status transition needed.
                self.invoke { delegate in
                    delegate?.authentication(self, didUpdate: session?.user, for: session)
                }

            case .unexpectedError(let error):
                self.invoke { [weak self] delegate in
                    delegate?.authentication(self, didFailWith: error, for: self?.session)
                }
            }
        }
    }
}
