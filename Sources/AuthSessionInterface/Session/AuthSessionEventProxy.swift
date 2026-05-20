//
//  AuthSessionEventProxy.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import Foundation


/// A specialization of ``AuthSessionEventPublisher`` that is initialized with a closure
/// for forwarding session events.
///
/// Concrete implementations (e.g., `SessionHandleEventProxy`) use this closure
/// to route events back to the session handle without a direct protocol conformance.
public protocol AuthSessionEventProxy: AuthSessionEventPublisher {

    /// Creates a proxy that forwards session events through the given closure.
    /// - Parameter eventListening: A closure invoked each time a session event is delivered.
    init(eventListening: @escaping @Sendable (AuthSessionEvent) -> Void)
}
