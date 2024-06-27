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

struct FooContainer: Codable, Equatable {
    var foo: Foo
}

struct Foo: Codable, Equatable {
    var foo: String

    public static func == (lhs: Foo, rhs: Foo) -> Bool {
        return lhs.foo == rhs.foo
    }
}
    
@available(iOS 15, *)
class LevelDBTests: TestsBase {
    
    override func asyncSetup() async {
        await super.asyncSetup()
        
        await levelDB.setDictionaryEncoder {(key: String, value: [String : Any]) -> Data? in
            do {
                let data = try JSONSerialization.data(withJSONObject: value)
                return data
            } catch {
                NSLog("Problem encoding data: \(error)")
                return nil
            }
        }
        await levelDB.setDictionaryDecoder {(key: String, data: Data) -> [String : Any]? in
            do {
                if let result = try JSONSerialization.jsonObject(with: data) as? [String : Any] {
                    return result
                } else {
                    return nil
                }
            } catch {
                NSLog("Problem decoding data: \(error)")
                return nil
            }
        }
    }
    
    func testInit() async {
        await asyncSetup()
        XCTAssertNotNil(levelDB, "Database should not be nil")
        guard levelDB != nil else {
            print("\(Date.secondsSinceReferenceDate) Database reference is not existent, failed to open / create database")
            XCTFail()
            return
        }
        await asyncTearDown()
    }
    
    var numberOfIterations = 2500
    
    func testDatabaseCreated() async {
        await asyncSetup()
        XCTAssertNotNil(levelDB, "Database should not be nil")
        await asyncTearDown()
    }
    
    func testExists() async {
        await asyncSetup()
        let exists = await levelDB.exists
        XCTAssertTrue(exists)
        await asyncTearDown()
    }
    
    func testContentIntegrity() async throws {
        await asyncSetup()
        guard let levelDB else {
            print("\(Date.secondsSinceReferenceDate) Database reference is not existent, failed to open / create database")
            XCTFail()
            return
        }
        let key = "dict1"
        let value1 = Foo(foo: "bar")
        try await levelDB.setValue(value1, forKey: key)
        var fooValue: Foo? = await levelDB.value(forKey: key)
        XCTAssertEqual(fooValue, value1, "Saving and retrieving should keep a dictionary intact")
        await levelDB.removeValue(forKey: "dict1")
        fooValue = await levelDB.value(forKey: key)
        XCTAssertNil(fooValue, "A deleted key should return nil")
        let value2 = Foo(foo: "bar")
        try await levelDB.setValue(FooContainer(foo: value2), forKey: key)
        //levelDB[key] = FooContainer(foo: value2) //["array" : value2]
        let fooContainerValue: FooContainer? = await levelDB.value(forKey: key)
        XCTAssertEqual(fooContainerValue?.foo, value2, "Saving and retrieving should keep an array intact")
    }
    
    func testKeysManipulation() async throws {
        await asyncSetup()
        guard let levelDB else {
            print("\(Date.secondsSinceReferenceDate) Database reference is not existent, failed to open / create database")
            XCTFail()
            return
        }
        let value = ["foo": "bar"]
        try await levelDB.setValue(value, forKey: "dict1")
        try await levelDB.setValue(value, forKey: "dict2")
        try await levelDB.setValue(value, forKey: "dict3")
        
        let keys = ["dict1", "dict2", "dict3"]
        var keysFromDB = await levelDB.allKeys()
        XCTAssertEqual(keysFromDB, keys, "-[LevelDB allKeys] should return the list of keys used to insert data")
        await levelDB.removeAllValues()
        keysFromDB = await levelDB.allKeys()
        XCTAssertEqual(keysFromDB, [], "The list of keys should be empty after removing all values from the database")
        await asyncTearDown()
    }
    
    func testEnumerateKeysAndDictionaries() async {
        await asyncSetup()
        guard let levelDB else {
            print("\(Date.secondsSinceReferenceDate) Database reference is not existent, failed to open / create database")
            XCTFail()
            return
        }
        let value = ["foo": "bar"]
        try? await levelDB.setValue(value, forKey: "dict1")
        try? await levelDB.setValue(value, forKey: "dict2")
        try? await levelDB.setValue(value, forKey: "dict3")
        
        await levelDB.enumerateKeysAndDictionaries(backward: false, startingAtKey: nil, andPrefix: "dic") { key, value, stop in
            print(key)
            print(value)
            XCTAssertNotNil(value["foo"])
        }
        await asyncTearDown()
    }
    
    func testRemovingKeysWithPrefix() async {
        await asyncSetup()
        guard let levelDB = levelDB else {
            print("\(Date.secondsSinceReferenceDate) Database reference is not existent, failed to open / create database")
            XCTFail()
            return
        }
        let value = ["foo": "bar"]
        try? await levelDB.setValue(value, forKey: "dict1")
        try? await levelDB.setValue(value, forKey: "dict2")
        try? await levelDB.setValue(value, forKey: "dict3")
        try? await levelDB.setValue(["array" : [1, 2, 3]], forKey: "array1")
        await levelDB.removeAllValuesWithPrefix("dict")
        let keysFromDB = await levelDB.allKeys()
        XCTAssertEqual(keysFromDB.count, Int(1), "There should be only 1 key remaining after removing all those prefixed with 'dict'")
        await asyncTearDown()
    }
    
    func nPairs(_ n: Int) async throws -> [[Any]] {
        guard let levelDB = levelDB else {
            print("\(Date.secondsSinceReferenceDate) Database reference is not existent, failed to open / create database")
            return [[]]
        }
        var pairs = [[Any]]()
        for i in 0..<n {
            var r: Int
            var key: String
            repeat {
#if os(Linux)
                r = Int(random() % (5000 + 1))
#else
                r = Int(arc4random_uniform(5000))
#endif
                key = "\(r)"
            } while await levelDB.valueExistsForKey(key)
            let value = ["array" : [r, i]]
            pairs.append([key, value])
            try await levelDB.setValue(value, forKey: key)
        }
        pairs.sort{
            let obj1 = $0[0] as! String
            let obj2 = $1[0] as! String
            return obj1 < obj2
        }
        
        return pairs
    }
    
    func testForwardKeyEnumerations() async throws {
        await asyncSetup()
        guard let levelDB = levelDB else {
            print("\(Date.secondsSinceReferenceDate) Database reference is not existent, failed to open / create database")
            XCTFail()
            return
        }
        var r: Int
        let pairs = try await self.nPairs(numberOfIterations)
        // Test that enumerating the whole set yields keys in the correct orders
        r = 0
        await levelDB.enumerateKeys() { lkey, stop in
            let pair = pairs[r]
            let key = pair[0]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            r += 1
        }
        // Test that enumerating the set by starting at an offset yields keys in the correct orders
        r = 432
        await levelDB.enumerateKeys(backward: false, startingAtKey: pairs[r][0] as? String, andPrefix: nil, callback: { lkey, stop in
            let pair = pairs[r]
            let key = pair[0]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            r += 1
        })
        await asyncTearDown()
    }
    
    func testBackwardKeyEnumerations() async throws {
        await asyncSetup()
        guard let levelDB = levelDB else {
            print("\(Date.secondsSinceReferenceDate) Database reference is not existent, failed to open / create database")
            XCTFail()
            return
        }
        let pairs = try await self.nPairs(numberOfIterations)
        // Test that enumerating the whole set backwards yields keys in the correct orders
        var r = pairs.count - 1
        await levelDB.enumerateKeys(backward: true, startingAtKey: nil, andPrefix: nil, callback: { lkey, stop in
            let pair = pairs[r]
            let key = pair[0]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            r -= 1
        })
        // Test that enumerating the set backwards at an offset yields keys in the correct orders
        r = 567
        await levelDB.enumerateKeys(backward: true, startingAtKey: pairs[r][0] as? String, andPrefix: nil, callback: { lkey, stop in
            let pair = pairs[r]
            let key = pair[0]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            r -= 1
        })
        await asyncTearDown()
    }
    
    func testBackwardPrefixedEnumerationsWithStartingKey() async throws {
        await asyncSetup()
        guard let levelDB = levelDB else {
            print("\(Date.secondsSinceReferenceDate) Database reference is not existent, failed to open / create database")
            XCTFail()
            return
        }
        let valueFor = {(i: Int) -> [String : Int] in
            return ["key" : i]
        }
        let pairs = ["tess:0" : valueFor(0), "tesa:0" : valueFor(0), "test:1" : valueFor(1), "test:2" : valueFor(2), "test:3" : valueFor(3), "test:4" : valueFor(4)]
        var i = 3
        try await levelDB.addEntriesFromDictionary(pairs)
        await levelDB.enumerateKeys(backward: true, startingAtKey: "test:3", andPrefix: "test", callback: { lkey, stop in
            let key = "test:\(i)"
            XCTAssertEqual(lkey, key, "Keys should be restricted to the prefixed region")
            i -= 1
        })
        XCTAssertEqual(i, 0, "")
        await asyncTearDown()
    }
    
    func testForwardPrefixedEnumerationsWithStartingKey() async throws {
        await asyncSetup()
        guard let levelDB = levelDB else {
            print("\(Date.secondsSinceReferenceDate) Database reference is not existent, failed to open / create database")
            XCTFail()
            return
        }
        let valueFor = {(i: Int) -> [String : Int] in
            return ["key" : i]
        }
        let pairs = ["tess:0" : valueFor(0), "tesa:0" : valueFor(0), "test:1" : valueFor(1), "test:2" : valueFor(2), "test:3" : valueFor(3), "test:4" : valueFor(4), "tesy:5" : valueFor(5)]
        var i = 1
        try await levelDB.addEntriesFromDictionary(pairs)
        await levelDB.enumerateKeys(backward: false, startingAtKey: "tesa:0", andPrefix: "test", callback: { lkey, stop in
            let key = "test:\(i)"
            XCTAssertEqual(lkey, key, "Keys should be restricted to the prefixed region")
            i += 1
        })
        XCTAssertEqual(i, 5, "")
        await asyncTearDown()
    }
    
    func testPrefixedEnumerations() async throws {
        await asyncSetup()
        guard let levelDB = levelDB else {
            print("\(Date.secondsSinceReferenceDate) Database reference is not existent, failed to open / create database")
            XCTFail()
            return
        }
        let valueFor = {(i: Int) -> [String : Int] in
            return ["key": i]
        }
        let pairs = ["tess:0" : valueFor(0), "tesa:0" : valueFor(0), "test:1" : valueFor(1), "test:2" : valueFor(2), "test:3" : valueFor(3), "test:4" : valueFor(4)]
        var i = 4
        try await levelDB.addEntriesFromDictionary(pairs)
        await levelDB.enumerateKeys(backward: true, startingAtKey: nil, andPrefix: "test", callback: { lkey, stop in
            let key = "test:\(i)"
            XCTAssertEqual(lkey, key, "Keys should be restricted to the prefixed region")
            i -= 1
        })
        XCTAssertEqual(i, 0, "")
        await levelDB.removeAllValues()
        try await levelDB.addEntriesFromDictionary(["tess:0": valueFor(0), "test:1": valueFor(1), "test:2": valueFor(2), "test:3": valueFor(3), "test:4": valueFor(4), "tesu:5": valueFor(5)])
        i = 4
        await asyncTearDown()
    }
}
