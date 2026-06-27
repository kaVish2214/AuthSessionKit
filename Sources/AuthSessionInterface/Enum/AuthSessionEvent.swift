// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Events emitted during the authentication session lifecycle.
///
/// Subscribe to these events through an ``AuthSessionEventProxy``
/// to track session state changes in real time.
public enum AuthSessionEvent: Sendable {

    /// The session provider is currently fetching or refreshing a session.
    case fetchingSession

    /// The session fetch or refresh failed with an underlying error.
    /// - Parameter _: The error that caused the fetch to fail.
    case sessionFetchFailed(Error)

    /// The session was successfully fetched or refreshed.
    case sessionFetched(isInitialFetch: Bool)
    
    /// The user has been signed out.
    /// - Parameter error: The error that triggered the sign-out, or `nil` if the user signed out voluntarily.
    case sessionSignedOut(error: Error?)

    /// The user has successfully signed in.
    case sessionSignIn
    
    /// The session or its associated user data was updated.
    /// - Parameter _: The updated session, or `nil` if the session was cleared.
    case sessionUpdated((any AuthSessionProtocol)?)

    /// An unexpected error occurred during a session operation (e.g., a failed sign-out attempt).
    /// - Parameter _: The ``AuthSessionError`` describing the failure.
    case unexpectedError(AuthSessionError)
}
