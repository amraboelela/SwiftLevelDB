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
        let result = shellWithPipes("ls -l", "grep root", "grep dotnet")
        print("result: \(result)")
    }
    
    func testReportMemory() {
        reportMemory()
    }
}
