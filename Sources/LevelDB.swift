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
public typealias LevelDBKeyValueBlock = (String, Any, UnsafeMutablePointer<Bool>) -> Void
public typealias LevelDBLazyKeyValueBlock = (String, () -> Any?, UnsafeMutablePointer<Bool>) -> Void

#if swift(>=3.0)
    public let stringEncoding = String.Encoding.utf8.rawValue
#else
    public let stringEncoding = NSUTF8StringEncoding
    typealias UnsafeMutableRawPointer = UnsafeMutablePointer<Void>
    public typealias Data = NSData
    public typealias Any = AnyObject
#endif

#if swift(>=3.0)
public func SearchPathForDirectoriesInDomains(_ directory: FileManager.SearchPathDirectory, _ domainMask: FileManager.SearchPathDomainMask, _ expandTilde: Bool) -> [String] {
    let bundle = Bundle.main
    let bundlePath = bundle.bundlePath
    if domainMask == .userDomainMask {
        switch directory {
        case .libraryDirectory:
            return [bundlePath + "/Library"]
        case .documentDirectory:
            return [bundlePath + "/Documents"]
        default:
            break
        }
    }
    return [""]
}
#endif

public class LevelDB {
    
    var name: String
    var path: String
    public var encoder: (String, Any) -> Data?
    public var decoder: (String, Data) -> Any?
    var db: UnsafeMutableRawPointer?
    
    // MARK: - Life cycle
    
    required public init(path: String, name: String) {
        self.name = name
        self.path = path
        self.encoder = {key, value in
            #if DEBUG
                var onceToken: dispatch_once_t
                dispatch_once(onceToken, {() -> Void in
                    print("No encoder block was set for this database [\(name)]")
                    print("Using a convenience encoder/decoder pair using NSKeyedArchiver.")
                })
            #endif
            #if swift(>=3.0)
                return Data(bytes: key.cString, count: key.length)
            #else
                return NSData(bytes: key.cString, length: key.length)
            #endif
        }
        self.decoder = {key, data in
            return ""
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
        //print("path: \(path)")
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
        return self.init(path: path, name: name)
    }
    
    class func getLibraryPath() -> String {
        #if swift(>=3.0)
            var paths = SearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        #else
            var paths = NSSearchPathForDirectoriesInDomains(.LibraryDirectory, .UserDomainMask, true)
        #endif
        return paths[0]
    }
    
    
    // MARK: - Accessors
    
    public func description() -> String {
        return "<LevelDB:\(self) path: \(path)>"
    }
    
    public func setObject(_ value: Any?, forKey key: String) {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return
        }
        if let newValue = value {
            var status = 0
            if var data = encoder(key, newValue) {
                #if swift(>=3.0)
                    data.withUnsafeMutableBytes { (mutableBytes: UnsafeMutablePointer<UInt8>) -> () in
                        status = levelDBItemPut(db, key.cString, key.length, mutableBytes, data.count)
                    }
                #else
                    status = levelDBItemPut(db, key.cString, key.length, data.mutableBytes, data.length)
                #endif
                if status != 0 {
                    print("setObject: Problem storing key/value pair in database")
                }
            } else {
                print("Error: setObject: encoder(key, newValue) returned nil, key: \(key), newValue: \(newValue)")
            }
        } else {
            print("setObject: newValue is nil")
            levelDBItemDelete(db, key.cString, key.length)
        }
    }
    
    public subscript(key: String) -> Any? {
        get {
            // return an appropriate subscript value here
            return objectForKey(key)
        }
        set(newValue) {
            // perform a suitable setting action here
            setObject(newValue, forKey: key)
        }
    }
    
    public func addEntriesFromDictionary(_ dictionary: [String: Any]) {
        for (key, value) in dictionary {
            self[key] = value
        }
    }
    
    public func objectForKey(_ key: String) -> Any? {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return nil
        }
        #if swift(>=3.0)
            var rawData: UnsafeMutableRawPointer? = nil
        #else
            var rawData: UnsafeMutableRawPointer = nil
        #endif
        var rawDataLength: Int = 0
        let status = levelDBItemGet(db, key.cString, key.length, &rawData, &rawDataLength)
        if status != 0 {
            return nil
        }
        #if swift(>=3.0)
            if let rawData = rawData {
                let data = Data(bytes: rawData, count: rawDataLength)
                return decoder(key, data)
            } else {
                return nil
            }
        #else
            let data = NSData(bytes: rawData, length: rawDataLength)
            return decoder(key, data)
        #endif
    }
    
    public func objectsForKeys(_ keys: [String]) -> [Any?] {
        var result = [Any?]()
        for key in keys {
            result.append(self[key])
        }
        return result
    }
    
    public func objectExistsForKey(_ key: String) -> Bool {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return false
        }
        #if swift(>=3.0)
            var rawData: UnsafeMutableRawPointer? = nil
        #else
            var rawData: UnsafeMutableRawPointer = nil
        #endif
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
            #if swift(>=3.0)
                var iKey: UnsafeMutablePointer<Int8>? = nil
            #else
                var iKey: UnsafeMutablePointer<Int8> = nil
            #endif
            var iKeyLength: Int = 0
            levelDBIteratorGetKey(iterator, &iKey, &iKeyLength)
            #if swift(>=3.0)
                if let iKey = iKey {
                if prefixLen > 0 {
                if memcmp(iKey, prefixPtr, min(prefixLen, iKeyLength)) != 0 {
                break;
                }
                }
                }
            #else
                if prefixLen > 0 {
                    if memcmp(iKey, prefixPtr, min(prefixLen, iKeyLength)) != 0 {
                        break;
                    }
                }
            #endif
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
    
    public func dictionaryByFilteringWithPredicate(_ predicate: NSPredicate) -> [String : Any] {
        var results = [String : Any]()
        
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
        let iterator = levelDBIteratorNew(db)
        var stop = false
        #if swift(>=3.0)
            guard let iteratorPointer = iterator else {
            print("iterator is nil")
            return
            }
            _startIterator(iteratorPointer, backward: backward, prefix: prefix, start: key)
        #else
            _startIterator(iterator, backward: backward, prefix: prefix, start: key)
        #endif
        while levelDBIteratorIsValid(iterator) {
            #if swift(>=3.0)
                var iKey: UnsafeMutablePointer<Int8>? = nil
            #else
                var iKey: UnsafeMutablePointer<Int8> = nil
            #endif
            var iKeyLength: Int = 0
            levelDBIteratorGetKey(iterator, &iKey, &iKeyLength)
            #if swift(>=3.0)
                if let iKey = iKey {
                    if let prefix = prefix {
                        if memcmp(iKey, prefix.cString, min(prefix.length, iKeyLength)) != 0 {
                        break
                        }
                    }
                    if let iKeyString = NSString(bytes: iKey, length: iKeyLength, encoding: stringEncoding)?._bridgeToSwift() { 
                        if let predicate = predicate {
                            var iData: UnsafeMutableRawPointer? = nil
                            var iDataLength: Int = 0
                            levelDBIteratorGetValue(iterator, &iData, &iDataLength)
                            if let iData = iData {
                                let v = decoder(iKeyString, Data(bytes: iData, count: iDataLength))
                                if predicate.evaluate(with: v) {
                                    block(iKeyString, &stop)
                                }
                            }
                        } else {
                            block(iKeyString, &stop)
                        }
                    }
                }
            #else
                if let prefix = prefix {
                    if memcmp(iKey, prefix.cString, min(prefix.length, iKeyLength)) != 0 {
                        break
                    }
                }
                if let iKeyString = NSString(bytes: iKey, length: iKeyLength, encoding: stringEncoding) as? String {
                    if let predicate = predicate {
                        var iData: UnsafeMutableRawPointer = nil
                        var iDataLength: Int = 0
                        levelDBIteratorGetValue(iterator, &iData, &iDataLength)
                        let v = decoder(iKeyString, NSData(bytes: iData, length: iDataLength))
                        if predicate.evaluateWithObject(v) {
                            block(iKeyString, &stop)
                        }
                    } else {
                        block(iKeyString, &stop)
                    }
                }
            #endif
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
        let iterator = levelDBIteratorNew(db)
        var stop = false
        #if swift(>=3.0)
            guard let iteratorPointer = iterator else {
            print("iterator is nil")
            return
            }
            _startIterator(iteratorPointer, backward: backward, prefix: prefix, start: key)
        #else
            _startIterator(iterator, backward: backward, prefix: prefix, start: key)
        #endif
        while levelDBIteratorIsValid(iterator) {
            #if swift(>=3.0)
                var iKey: UnsafeMutablePointer<Int8>? = nil
            #else
                var iKey: UnsafeMutablePointer<Int8> = nil
            #endif
            var iKeyLength: Int = 0
            levelDBIteratorGetKey(iterator, &iKey, &iKeyLength);
            #if swift(>=3.0)
                if let iKey = iKey {
                    if let prefix = prefix {
                        if memcmp(iKey, prefix.cString, min(prefix.length, iKeyLength)) != 0 {
                        break
                        }
                    }
                    if let iKeyString = NSString(bytes: iKey, length: iKeyLength, encoding: stringEncoding)?._bridgeToSwift() {
                        var iData: UnsafeMutableRawPointer? = nil
                        var iDataLength: Int = 0
                        levelDBIteratorGetValue(iterator, &iData, &iDataLength)
                        if let iData = iData, let v = decoder(iKeyString, Data(bytes: iData, count: iDataLength)) {
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
            #else
                if let prefix = prefix {
                    if memcmp(iKey, prefix.cString, min(prefix.length, iKeyLength)) != 0 {
                        break
                    }
                }
                if let iKeyString = NSString(bytes: iKey, length: iKeyLength, encoding: stringEncoding) as? String {
                    var iData: UnsafeMutableRawPointer = nil
                    var iDataLength: Int = 0
                    levelDBIteratorGetValue(iterator, &iData, &iDataLength)
                    if let v = decoder(iKeyString, NSData(bytes: iData, length: iDataLength)) {
                        if let predicate = predicate {
                            if predicate.evaluateWithObject(v) {
                                block(iKeyString, v, &stop)
                            }
                        } else {
                            block(iKeyString, v, &stop)
                        }
                    }
                }
            #endif
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
        let iterator = levelDBIteratorNew(db)
        var stop = false
        #if swift(>=3.0)
            guard let iteratorPointer = iterator else {
            print("iterator is nil")
            return
            }
            _startIterator(iteratorPointer, backward: backward, prefix: prefix, start: key)
        #else
            _startIterator(iterator, backward: backward, prefix: prefix, start: key)
        #endif
        while levelDBIteratorIsValid(iterator) {
            #if swift(>=3.0)
                var iKey: UnsafeMutablePointer<Int8>? = nil
            #else
                var iKey: UnsafeMutablePointer<Int8> = nil
            #endif
            var iKeyLength: Int = 0
            levelDBIteratorGetKey(iterator, &iKey, &iKeyLength);
            #if swift(>=3.0)
            if let iKey = iKey {
                if let prefix = prefix {
                    if memcmp(iKey, prefix.cString, min(prefix.length, iKeyLength)) != 0 {
                        break
                    }
                }
                if let iKeyString = NSString(bytes: iKey, length: iKeyLength, encoding: stringEncoding)?._bridgeToSwift() {
                    let getter : () -> Any? = {
                        var iData: UnsafeMutableRawPointer? = nil
                            var iDataLength: Int = 0
                            levelDBIteratorGetValue(iterator, &iData, &iDataLength);
                        if let iData = iData {
                            return self.decoder(iKeyString, Data(bytes: iData, count: iDataLength));
                        } else {
                            return nil
                        }
                    };
                    block(iKeyString, getter, &stop);
                }
            }
            #else
                if let prefix = prefix {
                    if memcmp(iKey, prefix.cString, min(prefix.length, iKeyLength)) != 0 {
                        break
                    }
                }
                if let iKeyString = NSString(bytes: iKey, length: iKeyLength, encoding: stringEncoding) as? String {
                    let getter : () -> Any? = {
                        var iData: UnsafeMutableRawPointer = nil
                        var iDataLength: Int = 0
                        levelDBIteratorGetValue(iterator, &iData, &iDataLength);
                        return self.decoder(iKeyString, NSData(bytes: iData, length: iDataLength));
                    };
                    block(iKeyString, getter, &stop);
                }
            #endif
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
                #if swift(>=3.0)
                    let startingKeyPtr = malloc(len)!.bindMemory(to: Int8.self, capacity: len)
                #else
                    let startingKeyPtr = UnsafeMutablePointer<Int8>(malloc(len))
                #endif
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
                #if swift(>=3.0)
                    var iKey: UnsafeMutablePointer<Int8>? = nil
                #else
                    var iKey: UnsafeMutablePointer<Int8> = nil
                #endif
                var iKeyLength: Int = 0
                levelDBIteratorGetKey(iterator, &iKey, &iKeyLength)
                #if swift(>=3.0)
                    if len > 0, let iKey = iKey {
                    let cmp = memcmp(iKey, startingKey.cString, len)
                    if cmp > 0 {
                    levelDBIteratorMoveBackward(iterator)
                    }
                    }
                #else
                    if len > 0 {
                        let cmp = memcmp(iKey, startingKey.cString, len)
                        if cmp > 0 {
                            levelDBIteratorMoveBackward(iterator)
                        }
                    }
                #endif
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
