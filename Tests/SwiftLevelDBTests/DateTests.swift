//
//  DateTests.swift
//  SwiftLevelDBAppTests
//
//  Created by Amr Aboelela on 6/29/22.
//

import XCTest
import Foundation
import Dispatch

@testable import SwiftLevelDB

class DateTests: BaseTestClass {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testSecondsSince1970() {
        let now = Date.secondsSince1970
        let now2 = Date.secondsSinceReferenceDate
        XCTAssertTrue(now - now2 > (1970 - 2001) * 360 * 24 * 60 * 60)
    }
    
    func testSecondsSinceReferenceDate() {
        let now = Date.secondsSince1970
        let now2 = Date.secondsSinceReferenceDate
        XCTAssertTrue(now - now2 > (1970 - 2001) * 360 * 24 * 60 * 60)
    }
}
