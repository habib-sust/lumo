#if os(iOS)

import Foundation
import LumoCore
import ManagedSettings

/// Translates opaque system tokens to and from the portable `TokenBlob` that LumoCore stores.
///
/// This is the entire reason LumoCore can stay Foundation-only: tokens cross the boundary as
/// bytes, so the reconciler never needs `ManagedSettings`.
///
/// Tokens are `Codable` but their contents are undocumented and unstable — iOS reissues them
/// unpredictably. So these bytes are treated strictly as a payload to hand back to the system,
/// never as an identity. Identity is the bucket slot.
public enum TokenCodec {

    /// Wrapper so the encoded form is a keyed object rather than a bare value.
    ///
    /// A bare `try encoder.encode(token)` produces whatever single-value shape the current OS
    /// happens to use, which would make our stored form hostage to an implementation detail we
    /// cannot see. A named key gives us somewhere to add a version marker if the shape ever
    /// changes under us.
    private struct TokenBox<T: Codable>: Codable {
        var v: Int
        var t: T

        init(_ token: T) {
            v = 1
            t = token
        }
    }

    public enum CodecError: Error, Equatable {
        case encodeFailed
        case decodeFailed
    }

    // MARK: - Application

    public static func blob(from token: ApplicationToken) throws -> TokenBlob {
        try encode(token)
    }

    public static func applicationToken(from blob: TokenBlob) throws -> ApplicationToken {
        try decode(ApplicationToken.self, from: blob)
    }

    // MARK: - Category

    public static func blob(from token: ActivityCategoryToken) throws -> TokenBlob {
        try encode(token)
    }

    public static func categoryToken(from blob: TokenBlob) throws -> ActivityCategoryToken {
        try decode(ActivityCategoryToken.self, from: blob)
    }

    // MARK: - Web domain

    public static func blob(from token: WebDomainToken) throws -> TokenBlob {
        try encode(token)
    }

    public static func webDomainToken(from blob: TokenBlob) throws -> WebDomainToken {
        try decode(WebDomainToken.self, from: blob)
    }

    // MARK: - Plumbing

    private static func encode<T: Codable>(_ token: T) throws -> TokenBlob {
        guard let data = try? JSONEncoder().encode(TokenBox(token)) else {
            throw CodecError.encodeFailed
        }
        return TokenBlob(raw: data)
    }

    /// Returns `nil`-free: throws rather than returning an optional, because a token that
    /// cannot be decoded is the token-rotation case and callers must handle it explicitly —
    /// silently skipping it would leave an app unshielded with nothing surfaced.
    private static func decode<T: Codable>(_ type: T.Type, from blob: TokenBlob) throws -> T {
        guard let box = try? JSONDecoder().decode(TokenBox<T>.self, from: blob.raw) else {
            throw CodecError.decodeFailed
        }
        return box.t
    }
}

#endif
