// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation


/// A type that represents an active authentication session.
///
/// Conforming types expose the credentials and metadata needed to
/// make authenticated requests, along with the ``AuthSessionUserProtocol``
/// describing the signed-in user.
public protocol AuthSessionProtocol: Sendable {

    /// The bearer token used to authorize API requests.
    var accessToken: String { get }

    /// The duration, in seconds, for which the session remains valid from the time it was issued.
    var expiresIn: TimeInterval { get }

    /// The absolute timestamp (seconds since reference date) at which the session expires.
    var expiresAt: TimeInterval { get }

    /// The type of user associated with this session.
    associatedtype SessionUser where SessionUser: AuthSessionUserProtocol

    /// The authenticated user who owns this session.
    var user: SessionUser { get }
}


extension AuthSessionProtocol {

    /// The remaining duration, in seconds, until the session expires.
    public var expiresIn: TimeInterval {
        let expiresAt = Date(timeIntervalSince1970: expiresAt)
        return max(expiresAt.timeIntervalSinceNow, 0)
    }

    /// Returns `true` if the session is expired or will expire within 120 seconds.
    ///
    /// The 120-second buffer accounts for network latency and clock drift.
    public var isSessionExpired: Bool {
        let expiresAt = Date(timeIntervalSince1970: expiresAt)
        return expiresAt.timeIntervalSinceNow < 120
    }
}
