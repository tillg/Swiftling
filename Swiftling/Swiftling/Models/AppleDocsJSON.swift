//
//  AppleDocsJSON.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import Foundation

// MARK: - Apple Documentation JSON Structure

/// Main structure for Apple Developer Documentation JSON
struct AppleDocJSON: Codable, Sendable {
    let schemaVersion: SchemaVersion?
    let identifier: Identifier?
    let metadata: Metadata?
    let abstract: [ContentItem]?
    let primaryContentSections: [PrimaryContentSection]?
    let topicSections: [TopicSection]?
    let seeAlsoSections: [SeeAlsoSection]?
    let references: [String: Reference]?
    let variants: [Variant]?
    let hierarchy: Hierarchy?

    struct SchemaVersion: Codable, Sendable {
        let major: Int
        let minor: Int
        let patch: Int
    }

    struct Identifier: Codable, Sendable {
        let url: String?
        let interfaceLanguage: String?
    }

    struct Metadata: Codable, Sendable {
        let title: String?
        let roleHeading: String?
        let role: String?
        let platforms: [Platform]?
        let modules: [Module]?

        struct Platform: Codable, Sendable {
            let name: String?
            let introducedAt: String?
        }

        struct Module: Codable, Sendable {
            let name: String?
        }
    }

    struct Hierarchy: Codable, Sendable {
        let paths: [[String]]?
    }
}

// MARK: - Content Items

/// Represents a documentation content item
struct ContentItem: Codable, Sendable {
    let type: String?  // Optional - some items don't have a type
    let text: String?
    let code: StringOrArray?  // Can be String or [String]
    let syntax: String?
    let content: [ContentItem]?
    let inlineContent: [InlineContent]?
    let header: String?
    let items: [ContentItem]?
    let style: String?
    let level: Int?
    let anchor: String?
}

/// Inline content within text
struct InlineContent: Codable, Sendable {
    let type: String?  // Optional for flexibility
    let text: String?
    let code: StringOrArray?  // Can be String or [String]
    let identifier: String?
    let isActive: Bool?
}

// MARK: - Sections

/// Primary content section (overview, declaration, discussion, etc.)
struct PrimaryContentSection: Codable, Sendable {
    let kind: String
    let content: [ContentItem]?
    let declarations: [Declaration]?
    let parameters: [Parameter]?
}

/// Code declaration
struct Declaration: Codable, Sendable {
    let tokens: [Token]
    let languages: [String]?
    let platforms: [String]?

    struct Token: Codable, Sendable {
        let kind: String
        let text: String
        let identifier: String?
    }
}

/// Parameter documentation
struct Parameter: Codable, Sendable {
    let name: String
    let content: [ContentItem]?
}

/// Topic section (grouping related topics)
struct TopicSection: Codable, Sendable {
    let title: String
    let identifiers: [String]?
    let generated: Bool?
}

/// See also section
struct SeeAlsoSection: Codable, Sendable {
    let title: String?
    let identifiers: [String]
}

// MARK: - References

/// Reference to other documentation items
struct Reference: Codable, Sendable {
    let title: String?
    let url: String?
    let identifier: String?
    let type: String?
    let kind: String?
    let abstract: [ContentItem]?
    let role: String?
    let fragments: [Fragment]?

    struct Fragment: Codable, Sendable {
        let kind: String
        let text: String
        let identifier: String?
    }
}

// MARK: - Variants

/// Language-specific variant
struct Variant: Codable, Sendable {
    let traits: [Trait]?
    let paths: [String]?

    struct Trait: Codable, Sendable {
        let interfaceLanguage: String?
    }
}
