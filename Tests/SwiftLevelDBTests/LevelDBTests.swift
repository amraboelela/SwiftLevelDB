//
//  LevelDBTests.swift
//  SwiftLevelDBAppTests
//
//  Created by Amr Aboelela on 1/13/22.
//

import XCTest
import Foundation
import Dispatch

@testable import SwiftLevelDB

class LevelDBTests: BaseTestClass {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testInit() {
        XCTAssertNotNil(db, "Database should not be nil")
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let dbPath = LevelDB.getLibraryPath()
        XCTAssertNotEqual(dbPath, "")
    }
}
