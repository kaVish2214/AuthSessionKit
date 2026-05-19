//
//  AuthSessionUserProtocol.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import Foundation


/// A type that represents the authenticated user associated with a session.
///
/// Conforming types must be `Hashable` and `Sendable`, making them safe
/// to use as dictionary keys, in sets, and across concurrency boundaries.
public protocol AuthSessionUserProtocol: Hashable, Sendable {

    /// A unique identifier for the authenticated user (e.g., a user ID or email).
    var identifier: String { get }
}

