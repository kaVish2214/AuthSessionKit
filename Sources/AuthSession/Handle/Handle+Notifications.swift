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

    /// Registers for `didBecomeActiveNotification` to trigger session validation when the app foregrounds.
    func startListeningApplicationNotifications() {
        notificationObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self, !self.isManualAuthenticationRequired else {
                return
            }
            self.validateLocalSessionOrAuthenticateIfNeeded()
        }
    }
}
