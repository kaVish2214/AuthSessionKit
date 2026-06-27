// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation


/// A type that describes the current state of an authentication session.
///
/// Conformers expose Boolean queries for each possible session state,
/// allowing UI layers to drive transitions without depending on a concrete enum.
public protocol AuthSessionStatusProtocol: Sendable, Equatable {

    /// Whether the session is being fetched or refreshed from the provider.
    var isSyncing: Bool { get }

    /// Whether the user is authenticated and the session is valid.
    var isSignedIn: Bool { get }

    /// Whether no active session exists — the user is signed out.
    var isSignedOut: Bool { get }

    /// Whether the session is undergoing local validation (e.g., expiry check).
    var isValidating: Bool { get }

    /// Whether a biometric authentication prompt is currently in progress.
    var isBiometricAuthentication: Bool { get }
}

extension AuthSessionStatusProtocol {

    /// Whether the session is in a transitional state that implies loading.
    public var isLoadingStatus: Bool {
        return isSyncing || isValidating || isBiometricAuthentication
    }
}
