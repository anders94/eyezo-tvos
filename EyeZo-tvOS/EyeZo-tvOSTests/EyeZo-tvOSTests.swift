//
//  EyeZo-tvOSTests.swift
//  EyeZo-tvOSTests
//
//  Created by Anders Brownworth on 5/16/26.
//

import Foundation
import Testing
@testable import EyeZo_tvOS

struct ServerURLNormalizationTests {

    @Test func bareHostGetsHTTPScheme() {
        #expect(ServerURLManager.normalizedServerURL(from: "example.com")?.absoluteString == "http://example.com")
    }

    @Test func portIsPreserved() {
        #expect(ServerURLManager.normalizedServerURL(from: "192.168.1.100:3000")?.absoluteString == "http://192.168.1.100:3000")
    }

    @Test func existingHTTPSSchemeIsKept() {
        #expect(ServerURLManager.normalizedServerURL(from: "https://example.com")?.absoluteString == "https://example.com")
    }

    @Test func schemeComparisonIgnoresCase() {
        #expect(ServerURLManager.normalizedServerURL(from: "HTTP://example.com")?.absoluteString == "HTTP://example.com")
    }

    @Test func trailingSlashesAreRemoved() {
        #expect(ServerURLManager.normalizedServerURL(from: "http://example.com/")?.absoluteString == "http://example.com")
        #expect(ServerURLManager.normalizedServerURL(from: "example.com/media/")?.absoluteString == "http://example.com/media")
    }

    @Test func surroundingWhitespaceIsTrimmed() {
        #expect(ServerURLManager.normalizedServerURL(from: "  https://example.com/ \n")?.absoluteString == "https://example.com")
    }

    @Test func emptyAndSchemeOnlyInputAreRejected() {
        #expect(ServerURLManager.normalizedServerURL(from: "") == nil)
        #expect(ServerURLManager.normalizedServerURL(from: "   ") == nil)
        #expect(ServerURLManager.normalizedServerURL(from: "http://") == nil)
        #expect(ServerURLManager.normalizedServerURL(from: "/") == nil)
    }
}
