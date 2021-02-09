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

class MainTests: BaseTestClass {
    
    var numberOfIterations = 2500
    
    func testDatabaseCreated() {
        XCTAssertNotNil(db, "Database should not be nil")
    }
    
    func testContentIntegrity() {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let key = "dict1"
        let value1 = Foo(foo: "bar")
        db[key] = value1
        var fooValue: Foo? = db[key]
        XCTAssertEqual(fooValue, value1, "Saving and retrieving should keep an dictionary intact")
        db.removeValueForKey("dict1")
        fooValue = db[key]
        XCTAssertNil(fooValue, "A deleted key should return nil")
        let value2 = Foo(foo: "bar")
        db[key] = FooContainer(foo: value2) //["array" : value2]
        let fooContainerValue: FooContainer? = db[key]
        XCTAssertEqual(fooContainerValue?.foo, value2, "Saving and retrieving should keep an array intact")
        //db.removeValuesForKeys(["array1"])
        //XCTAssertNil(db["array1"], "A key that was deleted in batch should return nil")
    }
    
    func testKeysManipulation() {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let value = ["foo": "bar"]
        db["dict1"] = value
        db["dict2"] = value
        db["dict3"] = value
        let keys = ["dict1", "dict2", "dict3"]
        let keysFromDB = db.allKeys()
        XCTAssertEqual(keysFromDB, keys, "-[LevelDB allKeys] should return the list of keys used to insert data")
        db.removeAllValues()
        XCTAssertEqual(db.allKeys(), [], "The list of keys should be empty after removing all values from the database")
    }
    
    func testRemovingKeysWithPrefix() {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let value = ["foo": "bar"]
        db["dict1"] = value
        db["dict2"] = value
        db["dict3"] = value
        db["array1"] = ["array" : [1, 2, 3]]
        db.removeAllValuesWithPrefix("dict")
        XCTAssertEqual(db.allKeys().count, Int(1), "There should be only 1 key remaining after removing all those prefixed with 'dict'")
    }
    
    /*func testDictionaryManipulations() {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let values: [String : [String : Any]] = ["key1": ["array" : [1, 2]], "key2": ["foo": "bar"], "key3": [:]]
        db.addEntriesFromDictionary(values)
        var keys = ["key1", "key2", "key3"]
        for key in keys {
            XCTAssertEqual(NSObject.fromAny(db[key]), NSObject.fromAny(values[key]), "Values should match between dictionary and db")
        }
        keys = ["key1", "key2", "key9"]
        let extractedValues = zip(keys, db.valuesForKeys(keys)).reduce([String:Any]()){ var d = $0; d[$1.0] = $1.1; return d }
        for key in keys {
            XCTAssertEqual(NSObject.fromAny(extractedValues[key]), NSObject.fromAny(values[key]), "Values should match between dictionary and db")
        }
    }
    
    func testPredicateFiltering() {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let predicate = NSPredicate { (obj, bindings) -> Bool in
            let dic = obj as! [String: Int]
            let price = dic["price"]!
            return price >= 25 && price <= 50
        }
        var resultKeys = [String]()
        var price : Int
        #if !os(Linux)
            arc4random_stir()
        #endif
        for i in 0..<numberOfIterations {
            let numberKey = "\(i)"
            #if os(Linux)
                price = Int(random() % (100 + 1))
            #else
                price = Int(arc4random_uniform(100))
            #endif
            if price >= 25 && price <= 50 {
                resultKeys.append(numberKey)
            }
            db[numberKey] = ["price": price]
        }
        resultKeys = resultKeys.sorted{$0 < $1}
        //XCTAssertEqual(db.keysByFilteringWith(predicate: predicate), resultKeys, "Filtering db keys with a predicate should return the same list as expected")
        //var allValues = db.dictionaryByFilteringWith(predicate: predicate)
        //XCTAssertEqual(allValues.keys.sorted{$0 < $1}, resultKeys, "A dictionary obtained by filtering with a predicate should yield the expected list of keys")
        var i = 0
        db.enumerateKeysWith(predicate: predicate, backward: false, startingAtKey: nil, andPrefix: nil, callback: { key, stop in
            XCTAssertEqual(key, resultKeys[i], "Enumerating by filtering with a predicate should yield the expected keys")
            i += 1
        })
        i = Int(resultKeys.count) - 1
        db.enumerateKeysWith(predicate: predicate, backward:true, startingAtKey: nil, andPrefix: nil, callback: { key, stop in
            XCTAssertEqual(key, resultKeys[i], "Enumerating backwards by filtering with a predicate should yield the expected keys")
            i -= 1
        })
        i = 0
        db.enumerateKeysAndValuesWith(predicate: predicate, backward: false, startingAtKey: nil, andPrefix: nil, callback: { key, value, stop in
            XCTAssertEqual(key, resultKeys[i], "Enumerating keys and values by filtering with a predicate should yield the expected keys")
            XCTAssertEqual(NSObject.fromAny(value), NSObject.fromAny(allValues[resultKeys[i]]), "Enumerating keys and values by filtering with a predicate should yield the expected values")
            i += 1
        })
        i = Int(resultKeys.count) - 1
        db.enumerateKeysAndValuesWith(predicate: predicate, backward: true, startingAtKey: nil, andPrefix: nil, callback: { key, value, stop in
            XCTAssertEqual(key, resultKeys[i], "Enumerating keys and values by filtering with a predicate should yield the expected keys")
            XCTAssertEqual(NSObject.fromAny(value), NSObject.fromAny(allValues[resultKeys[i]]), "Enumerating keys and values by filtering with a predicate should yield the expected values")
            i -= 1
        })
    }*/
    
    func nPairs(_ n: Int) -> [[Any]] {
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
            } while db.valueExistsForKey(key)
            let value = ["array" : [r, i]]
            pairs.append([key, value])
            db[key] = value
        }
        pairs.sort{
            let obj1 = $0[0] as! String
            let obj2 = $1[0] as! String
            return obj1 < obj2
        }
        
        return pairs
    }
    
    func testForwardKeyEnumerations() {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        var r: Int
        let pairs = self.nPairs(numberOfIterations)
        // Test that enumerating the whole set yields keys in the correct orders
        r = 0
        db.enumerateKeys() { lkey, stop in
            let pair = pairs[r]
            let key = pair[0]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            r += 1
        }
        // Test that enumerating the set by starting at an offset yields keys in the correct orders
        r = 432
        db.enumerateKeys(backward: false, startingAtKey: pairs[r][0] as? String, andPrefix: nil, callback: { lkey, stop in
            let pair = pairs[r]
            let key = pair[0]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            r += 1
        })
    }
    
    func testBackwardKeyEnumerations() {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        //var r: Int
        let pairs = self.nPairs(numberOfIterations)
        // Test that enumerating the whole set backwards yields keys in the correct orders
        var r = pairs.count - 1
        db.enumerateKeys(backward: true, startingAtKey: nil, andPrefix: nil, callback: { lkey, stop in
            let pair = pairs[r]
            let key = pair[0]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            r -= 1
        })
        // Test that enumerating the set backwards at an offset yields keys in the correct orders
        r = 567
        db.enumerateKeys(backward: true, startingAtKey: pairs[r][0] as? String, andPrefix: nil, callback: { lkey, stop in
            let pair = pairs[r]
            let key = pair[0]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            r -= 1
        })
    }
    
    func testBackwardPrefixedEnumerationsWithStartingKey() {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let valueFor = {(i: Int) -> [String : Int] in
            return ["key" : i]
        }
        let pairs = ["tess:0" : valueFor(0), "tesa:0" : valueFor(0), "test:1" : valueFor(1), "test:2" : valueFor(2), "test:3" : valueFor(3), "test:4" : valueFor(4)]
        var i = 3
        db.addEntriesFromDictionary(pairs)
        db.enumerateKeys(backward: true, startingAtKey: "test:3", andPrefix: "test", callback: { lkey, stop in
            let key = "test:\(i)"
            XCTAssertEqual(lkey, key, "Keys should be restricted to the prefixed region")
            i -= 1
        })
        XCTAssertEqual(i, 0, "")
    }
    
    func testForwardPrefixedEnumerationsWithStartingKey() {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let valueFor = {(i: Int) -> [String : Int] in
            return ["key" : i]
        }
        let pairs = ["tess:0" : valueFor(0), "tesa:0" : valueFor(0), "test:1" : valueFor(1), "test:2" : valueFor(2), "test:3" : valueFor(3), "test:4" : valueFor(4), "tesy:5" : valueFor(5)]
        var i = 1
        db.addEntriesFromDictionary(pairs)
        db.enumerateKeys(backward: false, startingAtKey: "tesa:0", andPrefix: "test", callback: { lkey, stop in
            let key = "test:\(i)"
            XCTAssertEqual(lkey, key, "Keys should be restricted to the prefixed region")
            i += 1
        })
        XCTAssertEqual(i, 5, "")
    }
    
    func testPrefixedEnumerations() {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        let valueFor = {(i: Int) -> [String : Int] in
            return ["key": i]
        }
        let pairs = ["tess:0" : valueFor(0), "tesa:0" : valueFor(0), "test:1" : valueFor(1), "test:2" : valueFor(2), "test:3" : valueFor(3), "test:4" : valueFor(4)]
        var i = 4
        db.addEntriesFromDictionary(pairs)
        db.enumerateKeys(backward: true, startingAtKey: nil, andPrefix: "test", callback: { lkey, stop in
            let key = "test:\(i)"
            XCTAssertEqual(lkey, key, "Keys should be restricted to the prefixed region")
            i -= 1
        })
        XCTAssertEqual(i, 0, "")
        db.removeAllValues()
        db.addEntriesFromDictionary(["tess:0": valueFor(0), "test:1": valueFor(1), "test:2": valueFor(2), "test:3": valueFor(3), "test:4": valueFor(4), "tesu:5": valueFor(5)])
        i = 4
        /*db.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: "test", callback: { lkey, value, stop in
            let key = "test:\(i)"
            XCTAssertEqual(lkey, key, "Keys should be restricted to the prefixed region")
            let dic = value as! [String : Int]
            XCTAssertEqual(dic["key"], i, "Values should be restricted to the prefixed region")
            i -= 1
        })
        XCTAssertEqual(i, 0, "")
        i = 1
        db.addEntriesFromDictionary(pairs)
        db.enumerateKeys(backward: false, startingAtKey: nil, andPrefix: "test", callback: { lkey, stop in
            let key = "test:\(i)"
            XCTAssertEqual(lkey, key, "Keys should be restricted to the prefixed region")
            i += 1
        })
        XCTAssertEqual(i, 5, "")
        i = 1
        db.enumerateKeysAndValues(backward: false, startingAtKey: nil, andPrefix: "test", callback: { lkey, value, stop in
            let key = "test:\(i)"
            XCTAssertEqual(lkey, key, "Keys should be restricted to the prefixed region")
            let dic = value as! [String : Int]
            XCTAssertEqual(dic["key"], i, "Values should be restricted to the prefixed region")
            i += 1
        })
        XCTAssertEqual(i, 5, "")*/
    }
    
    /*func testForwardKeyAndValueEnumerations() {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        var pairs = self.nPairs(numberOfIterations)
        // Test that enumerating the whole set yields pairs in the correct orders
        var r = 0
        db.enumerateKeysAndValues() { lkey, _value, stop in
            var pair = pairs[r]
            let key = pair[0]
            let value = pair[1]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            XCTAssertEqual(NSObject.fromAny(_value), NSObject.fromAny(value), "Values should be equal, given the ordering worked")
            r += 1
        }
        // Test that enumerating the set by starting at an offset yields pairs in the correct orders
        r = 432
        db.enumerateKeysAndValues(backward: false, startingAtKey: pairs[r][0] as? String, andPrefix: nil, callback: { lkey, _value, stop in
            var pair = pairs[r]
            let key = pair[0]
            let value = pair[1]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            XCTAssertEqual(NSObject.fromAny(_value), NSObject.fromAny(value), "Values should be equal, given the ordering worked")
            r += 1
        })
    }
    
    func testBackwardKeyAndValueEnumerations() {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        var pairs = self.nPairs(numberOfIterations)
        // Test that enumerating the whole set backwards yields pairs in the correct orders
        var r = pairs.count - 1
        db.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: nil, callback: { lkey, _value, stop in
            var pair = pairs[r]
            let key = pair[0]
            let value = pair[1]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            XCTAssertEqual(NSObject.fromAny(_value), NSObject.fromAny(value), "Values should be equal, given the ordering worked")
            r -= 1
        })
        // Test that enumerating the set backwards at an offset yields pairs in the correct orders
        r = 567
        db.enumerateKeysAndValues(backward: true, startingAtKey: pairs[r][0] as? String, andPrefix: nil, callback: { lkey, _value, stop in
            var pair = pairs[r]
            let key = pair[0]
            let value = pair[1]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            XCTAssertEqual(NSObject.fromAny(_value), NSObject.fromAny(value), "Values should be equal, given the ordering worked")
            r -= 1
        })
    }
    
    func testBackwardLazyKeyAndValueEnumerations() {
        guard let db = db else {
            print("\(Date.now) Database reference is not existent, failed to open / create database")
            return
        }
        var pairs = self.nPairs(numberOfIterations)
        // Test that enumerating the set backwards and lazily at an offset yields pairs in the correct orders
        var r = 567;
        /*db.enumerateKeysAndValuesLazily(backward: true, startingAtKey: pairs[r][0] as? String, andPrefix: nil, callback: { lkey, getter, stop in
            var pair = pairs[r]
            let key = pair[0]
            let value = pair[1]
            XCTAssertEqual(key as? String, lkey, "Keys should be equal, given the ordering worked")
            XCTAssertEqual(NSObject.fromAny(getter()), NSObject.fromAny(value), "Values should be equal, given the ordering worked")
            r -= 1
        })*/
        db.removeAllValues()
    }*/
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
