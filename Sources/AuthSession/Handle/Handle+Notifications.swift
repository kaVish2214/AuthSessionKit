//
//  Handle+Notifications.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import Foundation
import UIKit


// MARK: - Application Notifications

extension AuthSessionHandle {

    /// Registers for `didBecomeActiveNotification` to trigger session validation
    /// when the app returns to the foreground.
    ///
    /// On the **first** notification (typically at launch), the handler sets
    /// ``allowsSessionValidationFromNotifications`` without running validation,
    /// deferring to the provider's initial fetch. On **subsequent** foreground
    /// events, it calls ``validateLocalSessionOrAuthenticateIfNeeded()`` to
    /// re-check expiry and biometric status.
    ///
    /// Skipped entirely when ``isManualAuthenticationRequired`` is `true`.
    func startListeningApplicationNotifications() {
        notificationObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self, !self.isManualAuthenticationRequired else {
                return
            }
            // First activation: mark ready but skip validation to avoid
            // racing with the provider's initial session fetch.
            guard self.allowsSessionValidationFromNotifications else {
                self.enableSessionValidationFromNotification()
                return
            }
            self.validateLocalSessionOrAuthenticateIfNeeded()
        }
    }
}
