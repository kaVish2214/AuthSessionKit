// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation


/// A type that represents the authenticated user associated with a session.
///
/// Conforming types must be `Hashable` and `Sendable`, making them safe
/// to use as dictionary keys, in sets, and across concurrency boundaries.
public protocol AuthSessionUserProtocol: Hashable, Sendable {

    /// A unique identifier for the authenticated user (e.g., a user ID or email).
    var identifier: String { get }
}

