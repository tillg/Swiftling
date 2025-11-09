//
//  JSONDecodingUtilities.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import Foundation

// MARK: - Flexible Decoding Types

/// Helper type that can decode either a String or [String]
/// Useful for JSON APIs that inconsistently return single strings or arrays
enum StringOrArray: Codable, Sendable {
    case string(String)
    case array([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([String].self) {
            self = .array(array)
        } else {
            throw DecodingError.typeMismatch(
                StringOrArray.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or [String]",
                    underlyingError: nil
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        }
    }

    /// Get the string value, joining arrays with newlines
    var stringValue: String {
        switch self {
        case .string(let str):
            return str
        case .array(let arr):
            return arr.joined(separator: "\n")
        }
    }

    /// Get the array value, wrapping single strings in an array
    var arrayValue: [String] {
        switch self {
        case .string(let str):
            return [str]
        case .array(let arr):
            return arr
        }
    }
}

// MARK: - Decoding Error Helpers

extension DecodingError {
    /// Creates a clear, readable description of a decoding error
    /// - Parameter error: The decoding error
    /// - Returns: Human-readable error description
    static func readableDescription(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            let pathString = path.isEmpty ? "root" : path
            return "Type mismatch at '\(pathString)': expected \(type), \(context.debugDescription)"

        case .valueNotFound(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            let pathString = path.isEmpty ? "root" : path
            return "Value not found at '\(pathString)': expected \(type), \(context.debugDescription)"

        case .keyNotFound(let key, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            let pathString = path.isEmpty ? "root" : path
            return "Key not found: '\(key.stringValue)' at '\(pathString)', \(context.debugDescription)"

        case .dataCorrupted(let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            let pathString = path.isEmpty ? "root" : path
            return "Data corrupted at '\(pathString)': \(context.debugDescription)"

        @unknown default:
            return "Unknown decoding error: \(error.localizedDescription)"
        }
    }

    /// Creates a detailed error with context for debugging
    static func detailedDescription(_ error: DecodingError, data: Data?) -> String {
        var description = readableDescription(error)

        // Add data preview if available
        if let data = data, data.count < 1000 {
            if let jsonString = String(data: data, encoding: .utf8) {
                description += "\n\nJSON data:\n\(jsonString)"
            }
        } else if let data = data {
            description += "\n\nJSON data size: \(data.count) bytes (too large to display)"
        }

        return description
    }
}

// MARK: - Safe Decoding Helpers

extension JSONDecoder {
    /// Attempts to decode and returns a Result type with detailed error information
    func decodeSafely<T: Decodable>(_ type: T.Type, from data: Data) -> Result<T, DecodingError> {
        do {
            let decoded = try decode(type, from: data)
            return .success(decoded)
        } catch let error as DecodingError {
            return .failure(error)
        } catch {
            // Wrap unexpected errors as dataCorrupted
            let context = DecodingError.Context(
                codingPath: [],
                debugDescription: "Unexpected error: \(error.localizedDescription)",
                underlyingError: error
            )
            return .failure(.dataCorrupted(context))
        }
    }

    /// Decodes JSON with detailed error logging
    func decodeWithLogging<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        logPrefix: String = "🔴 JSON Decode Error"
    ) throws -> T {
        do {
            return try decode(type, from: data)
        } catch let error as DecodingError {
            let description = DecodingError.detailedDescription(error, data: data)
            print("\(logPrefix): \(description)")
            throw error
        }
    }
}
