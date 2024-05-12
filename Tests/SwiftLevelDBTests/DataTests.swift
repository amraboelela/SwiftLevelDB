//
//  DataTests.swift
//  SwiftLevelDBAppTests
//
//  Created by Amr Aboelela on 2/12/24.
//

import XCTest
import Foundation
import Dispatch

@testable import SwiftLevelDB
import XCTest

class DataExtensionTests: XCTestCase {
    
    func testHexEncodedString() {
        let data = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F]) // "Hello"
        let expectedString = "48656C6C6F"
        
        let hexEncodedString = data.hexEncodedString
        
        XCTAssertEqual(hexEncodedString, expectedString)
    }
    
    func testSimpleDescriptionUTF8() {
        // Given
        let data = "Hello".data(using: .utf8)!
        let expectedDescription = "Hello"
        
        // When
        let description = data.simpleDescription
        
        // Then
        XCTAssertEqual(description, expectedDescription)
    }
    
    func testSimpleDescriptionNonUTF8() {
        let data = "Hello".data(using: .utf8)!
        let expectedDescription = "Hello"
        
        let description = data.simpleDescription
        
        XCTAssertEqual(description, expectedDescription)
    }
}
