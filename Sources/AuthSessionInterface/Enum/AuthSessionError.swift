//
//  AuthSessionError.swift
//  AuthSessionKit
//
//  Created by kavi gevariya on 25/04/26.
//

import Foundation
import BiometricAuthInterface


/// Errors that can occur during authentication session operations.
///
/// `AuthSessionError` represents the various failure modes when creating,
/// validating, or maintaining an authentication session. Each case carries
/// enough context for callers to decide on a recovery strategy.
///
/// All cases provide a user-facing description through ``LocalizedError``
/// conformance.
public enum AuthSessionError: Error, Sendable {

    /// The session data is missing required fields or contains invalid values.
    case sessionMalformed

    /// The session has expired and is no longer valid.
    case sessionExpired

    /// A network request required for authentication failed.
    /// - Parameter error: The underlying network error.
    case networkFailure(error: Error)

    /// Biometric authentication (e.g., Face ID or Touch ID) failed.
    /// - Parameter error: The underlying biometric authentication error.
    case biometricAuthFailure(error: BiometricAuthenticationError)
    

    /// A request to update the user's data on the server failed.
    /// - Parameter error: The underlying error returned by the user-update request.
    case userUpdateFailure(error: Error)

    /// The sign-out operation failed with an underlying error.
    /// - Parameter error: The underlying error encountered during sign-out.
    case signingOutFailure(error: Error)
    
    /// The initial session fetch or a subsequent refresh failed.
    /// - Parameter error: The underlying error from the session provider.
    case sessionFetchFailed(error: Error)
}

// MARK: - LocalizedError

extension AuthSessionError: LocalizedError {

    /// A localized description of the error suitable for presenting to the user.
    public var errorDescription: String? {
        switch self {
        case .sessionMalformed:
            return "The authentication session is malformed."
        case .sessionExpired:
            return "The authentication session has timed out."
        case .networkFailure(let error):
            return "Network request failed: \(error.localizedDescription)"
        case .biometricAuthFailure(let error):
            return "Biometric authentication failed: \(error.localizedDescription)"
        case .userUpdateFailure(error: let error):
            return "User update request failed: \(error.localizedDescription)"
        case .signingOutFailure(error: let error):
            return "Sign-out failed: \(error.localizedDescription)"
        case .sessionFetchFailed(error: let error):
            return error.localizedDescription
        }
    }
}

