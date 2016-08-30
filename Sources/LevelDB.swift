//
//  LevelDB.swift
//
//  Copyright 2011-2016 Pave Labs. All rights reserved.
//
//  Modified by: Amr Aboelela <amraboelela@gmail.com>
//  Date: Aug 2016
//
//  See LICENCE for details.
//

import Foundation
import CLevelDB

public typealias LevelDBKeyBlock = (String, UnsafeMutablePointer<Bool>) -> Void
public typealias LevelDBKeyValueBlock = (String, NSObject, UnsafeMutablePointer<Bool>) -> Void
public typealias LevelDBLazyKeyValueBlock = (String, () -> NSObject?, UnsafeMutablePointer<Bool>) -> Void

public class LevelDB {
    
    var name: String
    var path: String
    public var encoder: (String, NSObject) -> NSData?
    public var decoder: (String, NSData) -> NSObject?
    var db: UnsafeMutableRawPointer?
    
    // MARK: - Life cycle
    
    required public init(path: String, name: String) {
        self.name = name
        self.path = path
        self.encoder = {(key: String, object: NSObject) -> NSData in
            #if DEBUG
                var onceToken: dispatch_once_t
                dispatch_once(onceToken, {() -> Void in
                    print("No encoder block was set for this database [\(name)]")
                    print("Using a convenience encoder/decoder pair using NSKeyedArchiver.")
                })
            #endif
            return NSData(bytes: key.cString, length: key.length)
        }
        self.decoder = {(key: String, data: NSData) -> NSObject in
            return data
        }
        do {
        #if swift(>=3.0)
            let dirpath =  NSURL(fileURLWithPath:path).deletingLastPathComponent?.path ?? ""
            let fm = FileManager.default
            try fm.createDirectory(atPath: dirpath, withIntermediateDirectories:true, attributes:nil)
        #else
            let dirpath =  NSURL(fileURLWithPath:path).URLByDeletingLastPathComponent?.path ?? ""
            let fm = NSFileManager.defaultManager()
            try fm.createDirectoryAtPath(dirpath, withIntermediateDirectories:true, attributes:nil)
        #endif
        }
        catch let error {
            print("Problem creating parent directory: \(error)")
        }
        self.db = levelDBOpen(path.cString)
    }
    
    deinit {
        self.close()
    }
    
    // MARK: - Class methods
    
    public class func databaseInLibraryWithName(_ name: String) -> LevelDB {
        #if swift(>=3.0)
            let path = NSURL(fileURLWithPath: getLibraryPath(), isDirectory: true).appendingPathComponent(name)?.path ?? ""
        #else
            let path = NSURL(fileURLWithPath: getLibraryPath(), isDirectory: true).URLByAppendingPathComponent(name).path ?? ""
        #endif
        return self.init(path:path, name:name)
    }
    
    class func getLibraryPath() -> String {
        var paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        return paths[0]
    }
    
    
    // MARK: - Accessors
    
    public func description() -> String {
        return "<LevelDB:\(self) path: \(path)>"
    }
    
    public func setObject(_ value:NSObject?, forKey key:String) {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return
        }
        if let newValue = value {
            if let data = encoder(key, newValue) {
                let status = levelDBItemPut(db, key.cString, key.length, data.mutableBytes, data.length)
                if status != 0 {
                    print("Problem storing key/value pair in database")
                }
            } else {
                print("Problem storing key/value pair in database")
            }
        } else {
            levelDBItemDelete(db, key.cString, key.length)
        }
    }
    
    public subscript(key: String) -> NSObject? {
        get {
            // return an appropriate subscript value here
            return objectForKey(key)
        }
        set(newValue) {
            // perform a suitable setting action here
            setObject(newValue, forKey: key)
        }
    }
    
    public func addEntriesFromDictionary(dictionary: [String : NSObject]) {
        for (key, value) in dictionary {
            self[key] = value
        }
    }
    
    public func objectForKey(_ key: String) -> NSObject? {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return nil
        }
        var rawData: UnsafeMutableRawPointer? = nil
        var rawDataLength: Int = 0
        let status = levelDBItemGet(db, key.cString, key.length, &rawData, &rawDataLength)
        if status != 0 {
            return nil
        }
        let data = NSData(bytes: rawData, length: rawDataLength)
        return decoder(key, data)
    }
    
    public func objectsForKeys(_ keys: [String]) -> [NSObject?] {
        var result = [NSObject?]() //(count: keys.count, repeatedValue: nil)
        //var index = 0
        for key in keys {
            result.append(self[key])
            //index += 1
        }
        return result
    }
    
    public func objectExistsForKey(_ key: String) -> Bool {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return false
        }
        var rawData: UnsafeMutableRawPointer? = nil
        var rawDataLength: Int = 0
        let status = levelDBItemGet(db, key.cString, key.length, &rawData, &rawDataLength)
        if status == 0 {
            free(rawData)
            return true
        } else {
            return false
        }
    }
    
    public func removeObjectForKey(_ key: String) {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return
        }
        let status = levelDBItemDelete(db, key.cString, key.length)
        if status != 0 {
            print("Problem removing object with key: \(key) in database")
        }
    }
    
    public func removeObjectsForKeys(_ keys: [String]) {
        for key in keys {
            removeObjectForKey(key)
        }
    }
    
    public func removeAllObjects() {
        self.removeAllObjectsWithPrefix("")
    }
    
    public func removeAllObjectsWithPrefix(_ prefix: String) {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return
        }
        let iterator = levelDBIteratorNew(db)
        let prefixPtr = prefix.cString
        let prefixLen = prefix.length
        
        if prefixLen > 0 {
            levelDBIteratorSeek(iterator, prefix.cString, prefixLen)
        } else {
            levelDBIteratorMoveToFirst(iterator)
        }
        while levelDBIteratorIsValid(iterator) {
            var iKey: UnsafeMutablePointer<Int8>? = nil
            var iKeyLength: Int = 0
            levelDBIteratorGetKey(iterator, &iKey, &iKeyLength)
            if let iKey = iKey {
            if prefixLen > 0 {
            if memcmp(iKey, prefixPtr, min(prefixLen, iKeyLength)) != 0 {
                break;
            }
            }
            }
            levelDBItemDelete(db, iKey, iKeyLength)
            levelDBIteratorMoveForward(iterator)
        }
        levelDBIteratorDelete(iterator)
    }
    
    public func allKeys() -> [String] {
        var keys = [String]()
        self.enumerateKeysUsingBlock({key, stop in
            keys.append(key)
        })
        return keys
    }
    
    public func keysByFilteringWithPredicate(_ predicate: NSPredicate) -> [String] {
        var keys = [String]()
        enumerateKeysAndObjectsWithPredicate(predicate, backward: false, startingAtKey: nil, andPrefix: nil, usingBlock: {key, obj, stop in
            keys.append(key)
        })
        return keys
    }
    
    public func dictionaryByFilteringWithPredicate(_ predicate: NSPredicate) -> [String : NSObject] {
        var results = [String : NSObject]()
        
        enumerateKeysAndObjectsWithPredicate(predicate, backward: false, startingAtKey: nil, andPrefix: nil, usingBlock: {key, obj, stop in
            results[key] = obj
        })
        return results
    }
    
    // MARK: - Enumeration
    
    public func enumerateKeys(backward backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, usingBlock block: LevelDBKeyBlock) {
        self.enumerateKeysWithPredicate(nil, backward: backward, startingAtKey: key, andPrefix: prefix, usingBlock: block)
    }
    
    public func enumerateKeysUsingBlock(_ block: LevelDBKeyBlock) {
        self.enumerateKeysWithPredicate(nil, backward: false, startingAtKey: nil, andPrefix: nil, usingBlock: block)
    }
    
    public func enumerateKeysWithPredicate(_ predicate: NSPredicate?, backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, usingBlock block: LevelDBKeyBlock) {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return
        }
        guard let iterator = levelDBIteratorNew(db) else {
            print("iterator is nil")
            return
        }
        var stop = false
        _startIterator(iterator, backward: backward, prefix: prefix, start: key)
        while levelDBIteratorIsValid(iterator) {
            var iKey: UnsafeMutablePointer<Int8>? = nil
            var iKeyLength: Int = 0
            levelDBIteratorGetKey(iterator, &iKey, &iKeyLength)
            if let iKey = iKey {
            if let prefix = prefix {
                if memcmp(iKey, prefix.cString, min(prefix.length, iKeyLength)) != 0 {
                    break
                }
            }
            if let iKeyString = NSString(bytes: iKey, length: iKeyLength, encoding: String.Encoding.utf8.rawValue) as? String {
                if let predicate = predicate {
                    var iData: UnsafeMutableRawPointer? = nil
                    var iDataLength: Int = 0
                    levelDBIteratorGetValue(iterator, &iData, &iDataLength)
                    let v = decoder(iKeyString, NSData(bytes: iData, length: iDataLength))
                    if predicate.evaluate(with: v) {
                        block(iKeyString, &stop)
                    }
                } else {
                    block(iKeyString, &stop)
                }
            }
            }
            if stop {
                break
            }
            backward ? levelDBIteratorMoveBackward(iterator) : levelDBIteratorMoveForward(iterator)
        }
        levelDBIteratorDelete(iterator)
    }
    
    public func enumerateKeysAndObjects(backward backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, usingBlock block: LevelDBKeyValueBlock) {
        
        enumerateKeysAndObjectsWithPredicate(nil, backward: backward, startingAtKey: key, andPrefix: prefix, usingBlock: block)
    }
    
    public func enumerateKeysAndObjectsUsingBlock(_ block: LevelDBKeyValueBlock) {
        enumerateKeysAndObjectsWithPredicate(nil, backward: false, startingAtKey: nil, andPrefix: nil, usingBlock: block)
    }
    
    public func enumerateKeysAndObjectsWithPredicate(_ predicate: NSPredicate?, backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, usingBlock block:LevelDBKeyValueBlock) {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return
        }
        guard let iterator = levelDBIteratorNew(db) else {
            print("iterator is nil")
            return
        }
        var stop = false
        _startIterator(iterator, backward: backward, prefix: prefix, start: key)
        while levelDBIteratorIsValid(iterator) {
            var iKey: UnsafeMutablePointer<Int8>? = nil
            var iKeyLength: Int = 0
            levelDBIteratorGetKey(iterator, &iKey, &iKeyLength);
            if let iKey = iKey {
                if let prefix = prefix {
                    if memcmp(iKey, prefix.cString, min(prefix.length, iKeyLength)) != 0 {
                        break
                    }
                }
                if let iKeyString = NSString(bytes: iKey, length: iKeyLength, encoding: String.Encoding.utf8.rawValue) as? String {
                    var iData: UnsafeMutableRawPointer? = nil
                    var iDataLength: Int = 0
                    levelDBIteratorGetValue(iterator, &iData, &iDataLength)
                    if let v = decoder(iKeyString, NSData(bytes: iData, length: iDataLength)) {
                        if let predicate = predicate {
                            if predicate.evaluate(with: v) {
                                block(iKeyString, v, &stop)
                            }
                        } else {
                            block(iKeyString, v, &stop)
                        }
                    }
                }
            }
            if (stop) {
                break;
            }
            backward ? levelDBIteratorMoveBackward(iterator) : levelDBIteratorMoveForward(iterator)
        }
        levelDBIteratorDelete(iterator);
    }
    
    public func enumerateKeysAndObjectsLazily(backward backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, usingBlock block:LevelDBLazyKeyValueBlock) {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return
        }
        guard let iterator = levelDBIteratorNew(db) else {
            print("iterator is nil")
            return
        }
        var stop = false
        _startIterator(iterator, backward: backward, prefix: prefix, start: key)
        while levelDBIteratorIsValid(iterator) {
            var iKey: UnsafeMutablePointer<Int8>? = nil
            var iKeyLength: Int = 0
            levelDBIteratorGetKey(iterator, &iKey, &iKeyLength);
            if let iKey = iKey {
            if let prefix = prefix {
                if memcmp(iKey, prefix.cString, min(prefix.length, iKeyLength)) != 0 {
                    break
                }
            }
            if let iKeyString = NSString(bytes: iKey, length: iKeyLength, encoding: String.Encoding.utf8.rawValue) as? String {
                let getter : () -> NSObject? = {
                    var iData: UnsafeMutableRawPointer? = nil
                    var iDataLength: Int = 0
                    levelDBIteratorGetValue(iterator, &iData, &iDataLength);
                    return self.decoder(iKeyString, NSData(bytes: iData, length: iDataLength));
                };
                block(iKeyString, getter, &stop);
            }
            }
            if (stop) {
                break;
            }
            backward ? levelDBIteratorMoveBackward(iterator) : levelDBIteratorMoveForward(iterator)
        }
        levelDBIteratorDelete(iterator);
    }
    
    // MARK: - Helper methods
    
    public func deleteDatabaseFromDisk() {
        self.close()
        do {
        #if swift(>=3.0)
            let fileManager = FileManager.default
            try fileManager.removeItem(atPath: path)
        #else
            let fileManager = NSFileManager.defaultManager()
            try fileManager.removeItemAtPath(path)
        #endif
        }
        catch let error as NSError {
            print("error deleting database at path \(path), \(error)")
        }
    }
    
    public func close() {
        if let db = db {
            levelDBDelete(db)
            self.db = nil
        }
    }
    
    public func closed() -> Bool {
        if let db = db {
            levelDBDelete(db)
            self.db = nil
        }
        return db == nil
    }
    
    // MARK: - Private methods
    
    private func _startIterator(_ iterator: UnsafeMutableRawPointer, backward: Bool, prefix: String?, start key: String?) {
        var startingKey: String
        if let prefix = prefix {
            startingKey = prefix
            if let key = key {
                if key.hasPrefix(prefix) {
                    startingKey = key
                }
            }
            let len = startingKey.length
            // If a prefix is provided and the iteration is backwards
            // we need to start on the next key (maybe discarding the first iteration)
            if backward {
                var i: Int = len - 1
                let startingKeyPtr = malloc(len)!.bindMemory(to: Int8.self, capacity: len) //malloc(len)
                memcpy(startingKeyPtr, startingKey.cString, len)
                var keyChar = startingKeyPtr
                while true {
                    if i < 0 {
                        levelDBIteratorMoveToLast(iterator)
                        break
                    }
                    keyChar += i
                    if keyChar[0] < 127 {
                        keyChar[0] += 1
                        levelDBIteratorSeek(iterator, startingKeyPtr, len)
                        if !levelDBIteratorIsValid(iterator) {
                            levelDBIteratorMoveToLast(iterator)
                        }
                        break
                    }
                    i -= 1
                }
                free(startingKeyPtr)
                if !levelDBIteratorIsValid(iterator) {
                    return
                }
                var iKey: UnsafeMutablePointer<Int8>? = nil
                var iKeyLength: Int = 0
                levelDBIteratorGetKey(iterator, &iKey, &iKeyLength)
                
                if len > 0, let iKey = iKey {
                    let cmp = memcmp(iKey, startingKey.cString, len)
                    if cmp > 0 {
                        levelDBIteratorMoveBackward(iterator)
                    }
                }
            } else {
                // Otherwise, we start at the provided prefix
                levelDBIteratorSeek(iterator, startingKey.cString, len)
            }
        } else if let key = key {
            levelDBIteratorSeek(iterator, key.cString, key.length)
        } else if backward {
            levelDBIteratorMoveToLast(iterator)
        } else {
            levelDBIteratorMoveToFirst(iterator)
        }
    }
}
