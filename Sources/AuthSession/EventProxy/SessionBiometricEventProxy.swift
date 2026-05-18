//
//  SessionBiometricEventProxy.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import UIKit
import AuthSessionInterface
import BiometricAuthInterface

/// A type that handles biometric authentication outcomes on behalf of the session handle.
///
/// ``SessionHandleEventProxy`` holds a weak reference to a conformer and forwards
/// biometric success/failure callbacks through it, keeping the handle decoupled
/// from ``BiometricAuthenticationDelegator``.
protocol SessionBiometricEventProxy: NSObjectProtocol, Sendable {

    /// The event proxy used to route errors back to the session event system.
    var sessionEventProxy: (any AuthSessionEventProxy)? { get }

    /// Transitions the session to the given status (e.g., `.signedIn` on biometric success).
    func set(sessionStatus status: AuthSessionStatus, function: String, file: String, line: Int)

    /// Handles a biometric authentication failure, delegating the sign-out
    /// decision to the session provider.
    func biometricAuthenticationFailure(with error: BiometricAuthenticationError)
    
    /// Notifies the handle that a biometric prompt is about to appear, so it
    /// can suppress notification-driven validation during the system alert.
    func biometricAuthenticationBeingAuthenticated()
}

extension SessionBiometricEventProxy {
    
    public func set(sessionStatus status: AuthSessionStatus, function: String = #function, file: String = #file, line: Int = #line) {
        self.set(sessionStatus: status, function: function, file: file, line: line)
    }
}
