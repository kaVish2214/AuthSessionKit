//
//  AuthSessionEventPublisher.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import Foundation


/// A type that delivers authentication session lifecycle events.
///
/// Session providers call ``publish(_:for:)`` to push ``AuthSessionEvent``
/// notifications through the proxy chain. A convenience overload omits the
/// provider parameter for internal callers.
///
/// Conforming types must inherit from `NSObject` (required by `NSObjectProtocol`).
public protocol AuthSessionEventPublisher: NSObjectProtocol, Sendable {

    /// Delivers a session lifecycle event, optionally associated with a specific provider.
    /// - Parameters:
    ///   - event: The event describing the current session state change.
    ///   - sessionProvider: The provider that originated the event, or `nil` for internal events.
    func publish(_ event: AuthSessionEvent, for sessionProvider: (any AuthSessionProviderProtocol)?)
}

extension AuthSessionEventPublisher {

    /// Convenience for delivering an event without a provider reference.
    public func publish(_ event: AuthSessionEvent) {
        self.publish(event, for: nil)
    }
}
