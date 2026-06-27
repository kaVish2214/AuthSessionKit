// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif



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
        
        let notificationName: Notification.Name

        #if os(iOS) || os(tvOS) || os(visionOS)
        notificationName = UIApplication.didBecomeActiveNotification
        #elseif os(macOS)
        notificationName = NSApplication.didBecomeActiveNotification
        #endif
        let notificationObserver = NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: nil) { [weak self] _ in
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
        self.setNotificationObserver(notificationObserver)
    }
}
