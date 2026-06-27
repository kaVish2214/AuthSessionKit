// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
