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
public typealias LevelDBKeyValueBlock = (String, [String : Any], UnsafeMutablePointer<Bool>) -> Void
public typealias LevelDBLazyKeyValueBlock = (String, () -> [String : Any]?, UnsafeMutablePointer<Bool>) -> Void

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

open class LevelDB {
    
    var name: String
    var path: String
    public var encoder: (String, [String : Any]) -> Data?
    public var decoder: (String, Data) -> [String : Any]?
    public var db: UnsafeMutableRawPointer?
    
    // MARK: - Life cycle
    
    required public init(path: String, name: String) {
        //NSLog("LevelDB init")
        self.name = name
        //NSLog("LevelDB self.name: \(name)")
        self.path = path
        //NSLog("LevelDB path: \(path)")
        self.encoder = { key, value in
            #if DEBUG
                NSLog("No encoder block was set for this database [\(name)]")
                NSLog("Using a convenience encoder/decoder pair using NSKeyedArchiver.")
            #endif
            return Data(bytes: key.cString, count: key.length)
        }
        //NSLog("LevelDB self.encoder")
        self.decoder = {key, data in
            return ["" : ""]
        }
        //NSLog("LevelDB self.decoder")
        #if os(Linux)
            do {
                let dirpath =  NSURL(fileURLWithPath:path).deletingLastPathComponent?.path ?? ""
                //NSLog("LevelDB dirpath: \(dirpath)")
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: dirpath) {
                    try fileManager.createDirectory(atPath: dirpath, withIntermediateDirectories:false, attributes:nil)
                }
                //NSLog("try FileManager.default")
            } catch {
                NSLog("Problem creating parent directory: \(error)")
            }
        #endif
        self.open()
    }
    
    convenience public init(name: String) {
        self.init(path: name, name: name)
    }
    
    deinit {
        self.close()
    }
    
    // MARK: - Class methods
    
    public class func getLibraryPath() -> String {
        #if os(Linux)
            var paths = SearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
            return paths[0]
        #else
            let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            return libraryDirectory.absoluteString
        #endif
        
    }
    
    // MARK: - Accessors
    
    open func description() -> String {
        return "<LevelDB:\(self) path: \(path)>"
    }
    
    open func setValue(_ value: [String : Any]?, forKey key: String) {
        guard let db = db else {
            NSLog("Database reference is not existent (it has probably been closed)")
            return
        }
        if let newValue = value {
            var status = 0
            if var data = encoder(key, newValue) {
                data.withUnsafeMutableBytes { (mutableBytes: UnsafeMutablePointer<UInt8>) -> () in
                    status = levelDBItemPut(db, key.cString, key.length, mutableBytes, data.count)
                }
                if status != 0 {
                    NSLog("setValue: Problem storing key/value pair in database")
                }
            } else {
                NSLog("Error: setValue: encoder(key, newValue) returned nil, key: \(key), newValue: \(newValue)")
            }
        } else {
            //NSLog("setValue: newValue is nil")
            levelDBItemDelete(db, key.cString, key.length)
        }
    }
    
    open subscript(key: String) -> [String : Any]? {
        get {
            // return an appropriate subscript value here
            return valueForKey(key)
        }
        set(newValue) {
            // perform a suitable setting action here
            setValue(newValue, forKey: key)
        }
    }
    
    open func addEntriesFromDictionary(_ dictionary: [String : [String : Any]]) {
        for (key, value) in dictionary {
            self[key] = value
        }
    }
    
    open func valueForKey(_ key: String) -> [String : Any]? {
        guard let db = db else {
            NSLog("Database reference is not existent (it has probably been closed)")
            return nil
        }
        var rawData: UnsafeMutableRawPointer? = nil
        var rawDataLength: Int = 0
        let status = levelDBItemGet(db, key.cString, key.length, &rawData, &rawDataLength)
        if status != 0 {
            return nil
        }
        if let rawData = rawData {
            let data = Data(bytes: rawData, count: rawDataLength)
            return decoder(key, data)
        } else {
            return nil
        }
    }
    
    open func valuesForKeys(_ keys: [String]) -> [[String : Any]?] {
        var result = [[String : Any]?]()
        for key in keys {
            result.append(self[key])
        }
        return result
    }
    
    open func valueExistsForKey(_ key: String) -> Bool {
        guard let db = db else {
            NSLog("Database reference is not existent (it has probably been closed)")
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
    
    open func removeValueForKey(_ key: String) {
        guard let db = db else {
            NSLog("Database reference is not existent (it has probably been closed)")
            return
        }
        let status = levelDBItemDelete(db, key.cString, key.length)
        if status != 0 {
            NSLog("Problem removing value with key: \(key) in database")
        }
    }
    
    open func removeValuesForKeys(_ keys: [String]) {
        for key in keys {
            removeValueForKey(key)
        }
    }
    
    open func removeAllValues() {
        self.removeAllValuesWithPrefix("")
    }
    
    open func removeAllValuesWithPrefix(_ prefix: String) {
        guard let db = db else {
            NSLog("Database reference is not existent (it has probably been closed)")
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
    
    open func allKeys() -> [String] {
        var keys = [String]()
        self.enumerateKeysUsingBlock({key, stop in
            keys.append(key)
        })
        return keys
    }
    
    open func keysByFilteringWithPredicate(_ predicate: NSPredicate) -> [String] {
        var keys = [String]()
        enumerateKeysAndValuesWithPredicate(predicate, backward: false, startingAtKey: nil, andPrefix: nil, usingBlock: {key, obj, stop in
            keys.append(key)
        })
        return keys
    }
    
    open func dictionaryByFilteringWithPredicate(_ predicate: NSPredicate) -> [String : Any] {
        var results = [String : Any]()
        
        enumerateKeysAndValuesWithPredicate(predicate, backward: false, startingAtKey: nil, andPrefix: nil, usingBlock: {key, obj, stop in
            results[key] = obj
        })
        return results
    }
    
    // MARK: - Enumeration
    
    open func enumerateKeys(backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, usingBlock block: LevelDBKeyBlock) {
        //NSLog("LevelDB enumerateKeys. backward: \(backward) startingAtKey key: \(key ?? "") perfix: \(prefix ?? "")")
        self.enumerateKeysWithPredicate(nil, backward: backward, startingAtKey: key, andPrefix: prefix, usingBlock: block)
    }
    
    open func enumerateKeysUsingBlock(_ block: LevelDBKeyBlock) {
        self.enumerateKeysWithPredicate(nil, backward: false, startingAtKey: nil, andPrefix: nil, usingBlock: block)
    }
    
    open func enumerateKeysWithPredicate(_ predicate: NSPredicate?, backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, usingBlock block: LevelDBKeyBlock) {
        guard let db = db else {
            NSLog("Database reference is not existent (it has probably been closed)")
            return
        }
        let iterator = levelDBIteratorNew(db)
        var stop = false
        guard let iteratorPointer = iterator else {
            NSLog("iterator is nil")
            return
        }
        _startIterator(iteratorPointer, backward: backward, prefix: prefix, start: key)
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
                let iKeyString = String.fromCString(iKey, length: iKeyLength)
                if predicate != nil {
                    var iData: UnsafeMutableRawPointer? = nil
                    var iDataLength: Int = 0
                    levelDBIteratorGetValue(iterator, &iData, &iDataLength)
                    if let iData = iData {
                        let v = decoder(iKeyString, Data(bytes: iData, count: iDataLength))
                        if predicate!.evaluate(with: v) {
                            block(iKeyString, &stop)
                        }
                    }
                } else {
                    block(iKeyString, &stop)
                }
            }
            if stop {
                break
            }
            backward ? levelDBIteratorMoveBackward(iterator) : levelDBIteratorMoveForward(iterator)
        }
        levelDBIteratorDelete(iterator)
    }
    
    open func enumerateKeysAndValues(backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, usingBlock block: LevelDBKeyValueBlock) {
        
        enumerateKeysAndValuesWithPredicate(nil, backward: backward, startingAtKey: key, andPrefix: prefix, usingBlock: block)
    }
    
    open func enumerateKeysAndValuesUsingBlock(_ block: LevelDBKeyValueBlock) {
        enumerateKeysAndValuesWithPredicate(nil, backward: false, startingAtKey: nil, andPrefix: nil, usingBlock: block)
    }
    
    open func enumerateKeysAndValuesWithPredicate(_ predicate: NSPredicate?, backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, usingBlock block:LevelDBKeyValueBlock) {
        guard let db = db else {
            NSLog("Database reference is not existent (it has probably been closed)")
            return
        }
        let iterator = levelDBIteratorNew(db)
        var stop = false
        guard let iteratorPointer = iterator else {
            NSLog("iterator is nil")
            return
        }
        _startIterator(iteratorPointer, backward: backward, prefix: prefix, start: key)
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
                let iKeyString = String.fromCString(iKey, length: iKeyLength)
                var iData: UnsafeMutableRawPointer? = nil
                var iDataLength: Int = 0
                levelDBIteratorGetValue(iterator, &iData, &iDataLength)
                if let iData = iData, let v = decoder(iKeyString, Data(bytes: iData, count: iDataLength)) {
                    if predicate != nil {
                        if predicate!.evaluate(with: v) {
                            block(iKeyString, v, &stop)
                        }
                    } else {
                        block(iKeyString, v, &stop)
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
    
    open func enumerateKeysAndValuesLazily(backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, usingBlock block:LevelDBLazyKeyValueBlock) {
        guard let db = db else {
            NSLog("Database reference is not existent (it has probably been closed)")
            return
        }
        let iterator = levelDBIteratorNew(db)
        var stop = false
        guard let iteratorPointer = iterator else {
            NSLog("iterator is nil")
            return
        }
        _startIterator(iteratorPointer, backward: backward, prefix: prefix, start: key)
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
                let iKeyString = String.fromCString(iKey, length: iKeyLength)
                let getter : () -> [String : Any]? = {
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
            if (stop) {
                break;
            }
            backward ? levelDBIteratorMoveBackward(iterator) : levelDBIteratorMoveForward(iterator)
        }
        levelDBIteratorDelete(iterator);
    }
    
    // MARK: - Helper methods
    
    open func deleteDatabaseFromDisk() {
        self.close()
        do {
            let fileManager = FileManager.default
            try fileManager.removeItem(atPath: path)
        } catch {
            NSLog("error deleting database at path \(path), \(error)")
        }
    }
    
    public func open() {
        self.db = levelDBOpen(path.cString)
    }
    
    open func close() {
        if let db = db {
            levelDBDelete(db)
            self.db = nil
        }
    }
    
    open func closed() -> Bool {
        if db != nil {
            close()
        }
        return db == nil
    }
    
    // MARK: - Private methods
    
    fileprivate func _startIterator(_ iterator: UnsafeMutableRawPointer, backward: Bool, prefix: String?, start key: String?) {
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
                let startingKeyPtr = malloc(len)!.bindMemory(to: Int8.self, capacity: len)
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
