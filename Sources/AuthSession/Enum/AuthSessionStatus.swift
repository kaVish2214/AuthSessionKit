// Copyright (c) 2026 kaVi Gevariya (@kaVish2214)
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import AuthSessionInterface

/// The current state of an authentication session.
///
/// Use this value to drive UI (e.g., show a loading indicator while
/// ``syncing`` or ``validating``) and to gate operations that require
/// a specific session state.
public enum AuthSessionStatus: Hashable, Sendable {

    /// The session is being fetched or refreshed from the provider.
    case syncing

    /// The user is authenticated and the session is valid.
    case signedIn

    /// No active session exists — the user is signed out.
    case signedOut

    /// The session is undergoing local validation (e.g., expiry check).
    case validating

    /// A biometric authentication prompt is currently in progress.
    case biometricAuthentication
}

// MARK: - State Queries

extension AuthSessionStatus {

    /// Whether the current state permits triggering biometric authentication.
    var allowsBiometricAuthentication: Bool {
        switch self {
        case .signedIn, .syncing, .validating: return true
        default: return false
        }
    }

    /// Whether the current state permits running local session validation.
    var allowsLocalValidation: Bool {
        switch self {
        case .signedIn, .syncing: return true
        default: return false
        }
    }
}

// MARK: - AuthSessionStatusProtocol

extension AuthSessionStatus: AuthSessionStatusProtocol {

    public var isSyncing: Bool {
        if case .syncing = self {
            return true
        }
        return false
    }
    
    public var isSignedIn: Bool {
        if case .signedIn = self {
            return true
        }
        return false
    }
    
    public var isSignedOut: Bool {
        if case .signedOut = self {
            return true
        }
        return false
    }
    
    public var isValidating: Bool {
        if case .validating = self {
            return true
        }
        return false
    }
    
    public var isBiometricAuthentication: Bool {
        if case .biometricAuthentication = self {
            return true
        }
        return false
    }
    
}
