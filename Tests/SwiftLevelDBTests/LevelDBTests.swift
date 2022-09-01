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

@available(iOS 13.0.0, *)
class LevelDBTests: BaseTestClass {
    
    func testInit() async {
        await asyncSetUp()
        XCTAssertNotNil(db, "Database should not be nil")
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        await asyncTearDown()
    }
}
