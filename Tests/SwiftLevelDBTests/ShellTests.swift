//
//  ShellTests.swift
//  SwiftLevelDBAppTests
//
//  Created by Amr Aboelela on 7/6/22.
//

import XCTest
import Foundation
import Dispatch

@testable import SwiftLevelDB

class ShellTests: BaseTestClass {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testShellWithPipe() {
        let result = try? shellWithPipes("top -l 1 -s 0", "grep PhysMem", "awk '{print $2 \"B of \" $1}'")
        XCTAssertTrue(result?.contains("error") == false)
        print("result: \(result ?? "")")
    }
    
    func testReportMemory() {
        reportMemory()
    }
}
