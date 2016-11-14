//
//  BaseTestClass.swift
//  SwiftLevelDBAppTests
//
//  Created by Mathieu D'Amours on 11/14/13
//  Modified by: Amr Aboelela on 8/23/16.
//

import XCTest
import Foundation
import Dispatch
import SwiftLevelDB

@testable import SwiftLevelDB

class BaseTestClass: XCTestCase {
    
    var db : LevelDB?
    //var lvldb_test_queue = DispatchQueue(label: "Create DB")
    
    override func setUp() {
        super.setUp()
        
        db = LevelDB(name: "TestDB")
        guard let db = db else {
            print("Database reference is not existent, failed to open / create database")
            return
        }
        db.removeAllObjects()
        db.encoder = {(key: String, value: Any) -> Data? in
            do {
                return try JSONSerialization.data(withJSONObject: value)
            } catch let error {
                print("Problem encoding data: \(error)")
                return nil
            }
        }
        db.decoder = {(key: String, data: Data) -> Any? in
            do {
                return try JSONSerialization.jsonObject(with: data)
            } catch let error {
                print("Problem decoding data: \(error)")
                return nil
            }
        }
    }
    
    override func tearDown() {
        db?.close()
        db = nil
        super.tearDown()
    }
}
