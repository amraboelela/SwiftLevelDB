//
//  DataTests.swift
//  SwiftLevelDBAppTests
//
//  Created by Amr Aboelela on 7/6/22.
//

import XCTest
import Foundation
import Dispatch

@testable import SwiftLevelDB

class DataTests: BaseTestClass {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testReportMemory() {
        reportMemory()
    }
}
