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

@available(iOS 13.0.0, *)
class TestsBase: XCTestCase {
    
    var levelDB : LevelDB!
    
    func asyncSetup() async {
        
        levelDB = LevelDB(name: "TestDB")
        await levelDB.removeAllValues()

        await levelDB.setEncoder {(key: String, value: Data) -> Data? in
            do {
                let data = value
                #if TwisterServer || DEBUG
                return data
                #else
                return try data.encryptedWithSaltUsing(key: myDevice.id)
                #endif
            } catch {
                NSLog("Problem encoding data: \(error)")
                return nil
            }
        }
        await levelDB.setDecoder {(key: String, data: Data) -> Data? in
            do {
                #if TwisterServer || DEBUG
                return data
                #else
                if let decryptedData = try data.decryptedWithSaltUsing(key: myDevice.id) {
                    return decryptedData
                } else {
                    return nil
                }
                #endif
            } catch {
                NSLog("Problem decoding data: \(data.simpleDescription) key: \(key) error: \(error)")
                return nil
            }
        }
    }
    
    func asyncTearDown() async {
        try! await levelDB?.deleteDatabaseFromDisk()
        levelDB = nil
    }
}
