//
//  AuthSessionEventPush.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import Foundation


/// A type that delivers authentication session lifecycle events.
///
/// Session providers call ``execute(_:for:)`` to push ``AuthSessionEvent``
/// notifications through the proxy chain. A convenience overload omits the
/// provider parameter for internal callers.
///
/// Conforming types must inherit from `NSObject` (required by `NSObjectProtocol`).
public protocol AuthSessionEventPush: NSObjectProtocol, Sendable {

    /// Delivers a session lifecycle event, optionally associated with a specific provider.
    /// - Parameters:
    ///   - event: The event describing the current session state change.
    ///   - sessionProvider: The provider that originated the event, or `nil` for internal events.
    func execute(_ event: AuthSessionEvent, for sessionProvider: (any AuthSessionProviderProtocol)?)
}

extension AuthSessionEventPush {

    /// Convenience for delivering an event without a provider reference.
    public func execute(_ event: AuthSessionEvent) {
        self.execute(event, for: nil)
    }
}
