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
    
    func testDayOfWeek() {
        var date = Date(timeIntervalSince1970: 1658086329) // Sunday 7/17/22
        var dayOfWeek = date.dayOfWeek
        XCTAssertEqual(dayOfWeek, 0)
        
        date = Date(timeIntervalSince1970: 1658345529) // Wednesday 7/20/22
        dayOfWeek = date.dayOfWeek
        XCTAssertEqual(dayOfWeek, 3)
    }
}
