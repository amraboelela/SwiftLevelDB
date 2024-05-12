//
//  StringTests.swift
//  SwiftLevelDBTests
//
//  Created by Amr Aboelela on 7/28/22.
//

import Foundation
import XCTest

@testable import SwiftLevelDB

class StringTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testTruncateShortString() {
        let shortString = "Short"
    
        let truncatedString = shortString.truncate(length: 10)
        
        XCTAssertEqual(truncatedString, "Short")
    }
    
    func testTruncateLongString() {
        let longString = "This is a very long string that exceeds the specified length"
        
        let truncatedString = longString.truncate(length: 20)
        
        XCTAssertEqual(truncatedString, "This is a very long …")
    }
    
    func testTruncateLongStringWithCustomTrailing() {
        let longString = "This is a very long string that exceeds the specified length"
        let customTrailing = "..."
        
        let truncatedString = longString.truncate(length: 20, trailing: customTrailing)
        
        XCTAssertEqual(truncatedString, "This is a very long " + customTrailing)
    }
    
    func testTruncateEmptyString() {
        let emptyString = ""
        
        let truncatedString = emptyString.truncate(length: 10)
        
        XCTAssertEqual(truncatedString, "")
    }
    
    func testLastMatchOf() {
        let myString = "Hi @jason @amr"
        let mentionPattern = "@[a-zA-z0-9]+\\b"
        let range = myString.lastMatch(of: mentionPattern)
        print("range: \(range)")
        XCTAssertNotNil(range)
    }
    
    func testReplaceLastMentionWithString() {
        let myString = "Hi @jason @amr"
        let result = myString.replaceLastMentionWith(string: "@ammoor")
        print("result: \(result)")
        XCTAssertEqual(result, "Hi @jason @ammoor")
    }
}
