//
//  AuthSessionDelegateEventPublisher.swift
//  RouteKit
//
//  Created by kavi gevariya on 18/05/26.
//

import Foundation


/// A type that delivers ``AuthSessionDelegateEvent`` values to a single, private listener.
///
/// `AuthSessionDelegateEventPublisher` is the outbound counterpart of
/// ``AuthSessionEventPublisher``. Where ``AuthSessionEventPublisher`` carries
/// raw lifecycle events from a session provider **into** the handle,
/// this protocol carries delegate-shaped events **out** of the handle to a
/// listener that wants the same signals without conforming to
/// ``AuthSessionDelegate`` publicly.
///
/// Implementations are typically wrapped by an ``AuthSessionDelegateEventProxy``
/// so the routing reaction lives inside an init-time closure.
public protocol AuthSessionDelegateEventPublisher: Sendable {

    /// Delivers a delegate-shaped event, optionally associated with the originating handle.
    /// - Parameters:
    ///   - event: The event mirroring an ``AuthSessionDelegate`` callback.
    ///   - sessionHandle: The handle that produced the event, or `nil` for synthetic emissions.
    func publish(_ event: AuthSessionDelegateEvent, for sessionHandle: (any AuthSessionHandleProtocol)?)
}
