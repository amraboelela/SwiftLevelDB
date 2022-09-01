//
//  MainTests.swift
//  SwiftLevelDBAppTests
//
//  Created by Mathieu D'Amours on 11/13/13.
//  Modified by: Amr Aboelela on 8/23/16.
//

import XCTest
import Foundation
import Dispatch

struct FooContainer: Codable, Equatable {
    var foo: Foo
}

struct Foo: Codable, Equatable {
    var foo: String

    public static func == (lhs: Foo, rhs: Foo) -> Bool {
        return lhs.foo == rhs.foo
    }
}

@available(iOS 13.0.0, *)
class MainTests: BaseTestClass {
    
    var numberOfIterations = 2500
    
    func testDatabaseCreated() async {
        await asyncSetUp()
        XCTAssertNotNil(db, "Database should not be nil")
        await asyncTearDown()
    }
    
    func testContentIntegrity() async throws {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let key = "dict1"
        let value1 = Foo(foo: "bar")
        try await db.setValue(value1, forKey: key)
        //db[key] = value1
        var fooValue: Foo? = await db.valueForKey(key) //db[key]
        XCTAssertEqual(fooValue, value1, "Saving and retrieving should keep an dictionary intact")
        await db.removeValueForKey("dict1")
        fooValue = await db.valueForKey(key)
        XCTAssertNil(fooValue, "A deleted key should return nil")
        let value2 = Foo(foo: "bar")
        try await db.setValue(FooContainer(foo: value2), forKey: key)
        //db[key] = FooContainer(foo: value2) //["array" : value2]
        let fooContainerValue: FooContainer? = await db.valueForKey(key)
        XCTAssertEqual(fooContainerValue?.foo, value2, "Saving and retrieving should keep an array intact")
        //db.removeValuesForKeys(["array1"])
        //XCTAssertNil(db["array1"], "A key that was deleted in batch should return nil")
    }
    
    func testKeysManipulation() async throws {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        await asyncSetUp()
        let value = ["foo": "bar"]
        try await db.setValue(value, forKey: "dict1")
        try await db.setValue(value, forKey: "dict2")
        try await db.setValue(value, forKey: "dict3")
        
        let keys = ["dict1", "dict2", "dict3"]
        var keysFromDB = await db.allKeys()
        XCTAssertEqual(keysFromDB, keys, "-[LevelDB allKeys] should return the list of keys used to insert data")
        await db.removeAllValues()
        keysFromDB = await db.allKeys()
        XCTAssertEqual(keysFromDB, [], "The list of keys should be empty after removing all values from the database")
        await asyncTearDown()
    }
    
    func testRemovingKeysWithPrefix() async throws {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        await asyncSetUp()
        let value = ["foo": "bar"]
        try await db.setValue(value, forKey: "dict1")
        try await db.setValue(value, forKey: "dict2")
        try await db.setValue(value, forKey: "dict3")
        try await db.setValue(["array" : [1, 2, 3]], forKey: "array1")
        await db.removeAllValuesWithPrefix("dict")
        let keysFromDB = await db.allKeys()
        XCTAssertEqual(keysFromDB.count, Int(1), "There should be only 1 key remaining after removing all those prefixed with 'dict'")
        await asyncTearDown()
    }
    
    func nPairs(_ n: Int) async throws -> [[Any]] {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
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
            } while await db.valueExistsForKey(key)
            let value = ["array" : [r, i]]
            pairs.append([key, value])
            try await db.setValue(value, forKey: key)
        }
        pairs.sort{
            let obj1 = $0[0] as! String
            let obj2 = $1[0] as! String
            return obj1 < obj2
        }
        
        return pairs
    }
    
    func testForwardKeyEnumerations() async throws {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        var r: Int
        let pairs = try await self.nPairs(numberOfIterations)
        // Test that enumerating the whole set yields keys in the correct orders
        r = 0
        await db.enumerateKeys() { lkey, stop in
            let pair = pairs[r]
            let key = pair[0]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            r += 1
        }
        // Test that enumerating the set by starting at an offset yields keys in the correct orders
        r = 432
        await db.enumerateKeys(backward: false, startingAtKey: pairs[r][0] as? String, andPrefix: nil, callback: { lkey, stop in
            let pair = pairs[r]
            let key = pair[0]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            r += 1
        })
    }
    
    func testBackwardKeyEnumerations() async throws {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let pairs = try await self.nPairs(numberOfIterations)
        // Test that enumerating the whole set backwards yields keys in the correct orders
        var r = pairs.count - 1
        await db.enumerateKeys(backward: true, startingAtKey: nil, andPrefix: nil, callback: { lkey, stop in
            let pair = pairs[r]
            let key = pair[0]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            r -= 1
        })
        // Test that enumerating the set backwards at an offset yields keys in the correct orders
        r = 567
        await db.enumerateKeys(backward: true, startingAtKey: pairs[r][0] as? String, andPrefix: nil, callback: { lkey, stop in
            let pair = pairs[r]
            let key = pair[0]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            r -= 1
        })
    }
    
    func testBackwardPrefixedEnumerationsWithStartingKey() async throws {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let valueFor = {(i: Int) -> [String : Int] in
            return ["key" : i]
        }
        let pairs = ["tess:0" : valueFor(0), "tesa:0" : valueFor(0), "test:1" : valueFor(1), "test:2" : valueFor(2), "test:3" : valueFor(3), "test:4" : valueFor(4)]
        var i = 3
        try await db.addEntriesFromDictionary(pairs)
        await db.enumerateKeys(backward: true, startingAtKey: "test:3", andPrefix: "test", callback: { lkey, stop in
            let key = "test:\(i)"
            XCTAssertEqual(lkey, key, "Keys should be restricted to the prefixed region")
            i -= 1
        })
        XCTAssertEqual(i, 0, "")
    }
    
    func testForwardPrefixedEnumerationsWithStartingKey() async throws {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let valueFor = {(i: Int) -> [String : Int] in
            return ["key" : i]
        }
        let pairs = ["tess:0" : valueFor(0), "tesa:0" : valueFor(0), "test:1" : valueFor(1), "test:2" : valueFor(2), "test:3" : valueFor(3), "test:4" : valueFor(4), "tesy:5" : valueFor(5)]
        var i = 1
        try await db.addEntriesFromDictionary(pairs)
        await db.enumerateKeys(backward: false, startingAtKey: "tesa:0", andPrefix: "test", callback: { lkey, stop in
            let key = "test:\(i)"
            XCTAssertEqual(lkey, key, "Keys should be restricted to the prefixed region")
            i += 1
        })
        XCTAssertEqual(i, 5, "")
    }
    
    func testPrefixedEnumerations() async throws {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let valueFor = {(i: Int) -> [String : Int] in
            return ["key": i]
        }
        let pairs = ["tess:0" : valueFor(0), "tesa:0" : valueFor(0), "test:1" : valueFor(1), "test:2" : valueFor(2), "test:3" : valueFor(3), "test:4" : valueFor(4)]
        var i = 4
        try await db.addEntriesFromDictionary(pairs)
        await db.enumerateKeys(backward: true, startingAtKey: nil, andPrefix: "test", callback: { lkey, stop in
            let key = "test:\(i)"
            XCTAssertEqual(lkey, key, "Keys should be restricted to the prefixed region")
            i -= 1
        })
        XCTAssertEqual(i, 0, "")
        await db.removeAllValues()
        try await db.addEntriesFromDictionary(["tess:0": valueFor(0), "test:1": valueFor(1), "test:2": valueFor(2), "test:3": valueFor(3), "test:4": valueFor(4), "tesu:5": valueFor(5)])
        i = 4
    }
}

extension Date {
    
    public static let oneMinute = TimeInterval(60)
    public static let oneHour = TimeInterval(60*60)
    public static let oneDay = TimeInterval(60*60*24)
    public static let thirtyDays = TimeInterval(30*24*60*60)
    public static let oneYear = TimeInterval(60*60*24*365.25)

    // MARK: - Accessors

    static var millisecondsSinceReferenceDate: Int {
        return Int(Date.timeIntervalSinceReferenceDate * 1000)
    }

    public static var now: Int {
        return Int(Date().timeIntervalSince1970)
    }
}
