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

public typealias LevelDBKeyCallback = (String, UnsafeMutablePointer<Bool>) -> Void

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
    public let serialQueue = DispatchQueue(label: "org.amr.leveldb")
    
    var name: String
    var path: String
	public var dictionaryEncoder: (String, [String : Any]) -> Data?
    public var dictionaryDecoder: (String, Data) -> [String : Any]?
    public var encoder: (String, Data) -> Data?
    public var decoder: (String, Data) -> Data?
    public var db: UnsafeMutableRawPointer?
    
    // MARK: - Life cycle
    
    required public init(path: String, name: String) {
        //NSLog("LevelDB init")
        self.name = name
        //NSLog("LevelDB self.name: \(name)")
        self.path = path
        //NSLog("LevelDB path: \(path)")
        self.dictionaryEncoder = { key, value in
            #if DEBUG
            NSLog("No encoder block was set for this database [\(name)]")
            NSLog("Using a convenience encoder/decoder pair using NSKeyedArchiver.")
            #endif
            return key.data(using: .utf8)
        }
        //NSLog("LevelDB self.encoder")
        self.dictionaryDecoder = {key, data in
            return ["" : ""]
        }
        self.encoder = { key, value in
            #if DEBUG
            NSLog("No encoder block was set for this database [\(name)]")
            NSLog("Using a convenience encoder/decoder pair using NSKeyedArchiver.")
            #endif
            return key.data(using: .utf8)
        }
        //NSLog("LevelDB self.encoder")
        self.decoder = {key, data in
            return Data()
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
            let paths = SearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
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
    
    open func setValue<T: Codable>(_ value: T, forKey key: String) {
        serialQueue.async {
            guard let db = self.db else {
                NSLog("Database reference is not existent (it has probably been closed)")
                return
            }
            do {
                let newData = try JSONEncoder().encode(value)
                var status = 0
                if let data = self.encoder(key, newData) {
                    var localData = data
                    localData.withUnsafeMutableBytes { (mutableBytes: UnsafeMutablePointer<UInt8>) -> () in
                        status = levelDBItemPut(db, key.cString, key.count, mutableBytes, data.count)
                    }
                    if status != 0 {
                        NSLog("setValue: Problem storing key/value pair in database, status: \(status), key: \(key), value: \(value)")
                    }
                } else {
                    NSLog("Error: setValue: encoder(key, newValue) returned nil, key: \(key), value: \(value)")
                }
            } catch {
                NSLog("LevelDB setValue error: \(error)")
            }
        }
    }
    
    open subscript<T:Codable>(key: String) -> T? {
        get {
            // return an appropriate subscript value here
            return valueForKey(key)
        }
        set (newValue) {
            // perform a suitable setting action here
            setValue(newValue, forKey: key)
        }
    }
    
    open func addEntriesFromDictionary<T: Codable>(_ dictionary: [String : T]) {
        for (key, value) in dictionary {
            self[key] = value
        }
    }
    
    open func valueForKey<T: Codable>(_ key: String) -> T? {
        var result: T?
        serialQueue.sync {
            guard let db = db else {
                NSLog("Database reference is not existent (it has probably been closed)")
                return
            }
            var rawData: UnsafeMutableRawPointer? = nil
            var rawDataLength: Int = 0
            let status = levelDBItemGet(db, key.cString, key.count, &rawData, &rawDataLength)
            if status != 0 {
                return
            }
            if let rawData = rawData {
                let data = Data(bytes: rawData, count: rawDataLength)
                if let decodedData = decoder(key, data) {
                    result = try? JSONDecoder().decode(T.self, from: decodedData)
                }
            }
        }
        return result
    }
    
    open func valuesForKeys<T: Codable>(_ keys: [String]) -> [T?] {
        var result = [T?]()
        for key in keys {
            result.append(self[key])
        }
        return result
    }
    
    open func valueExistsForKey(_ key: String) -> Bool {
        var result = false
        serialQueue.sync {
            guard let db = db else {
                NSLog("Database reference is not existent (it has probably been closed)")
                return
            }
            var rawData: UnsafeMutableRawPointer? = nil
            var rawDataLength: Int = 0
            let status = levelDBItemGet(db, key.cString, key.count, &rawData, &rawDataLength)
            if status == 0 {
                free(rawData)
                result = true
            }
        }
        return result
    }
    
    open func removeValueForKey(_ key: String) {
        serialQueue.sync {
            guard let db = db else {
                NSLog("Database reference is not existent (it has probably been closed)")
                return
            }
            let status = levelDBItemDelete(db, key.cString, key.count)
            if status != 0 {
                NSLog("Problem removing value with key: \(key) in database")
            }
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
        serialQueue.sync {
            guard let db = db else {
                NSLog("Database reference is not existent (it has probably been closed)")
                return
            }
            let iterator = levelDBIteratorNew(db)
            let prefixPtr = prefix.cString
            let prefixLen = prefix.count
            
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
    }
    
    open func allKeys() -> [String] {
        var keys = [String]()
        self.enumerateKeys() { key, stop in
            keys.append(key)
        }
        return keys
    }
    
    // MARK: - Enumeration
    
    open func enumerateKeys(backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, callback: LevelDBKeyCallback) {
        self.enumerateKeysWith(predicate: nil, backward: backward, startingAtKey: key, andPrefix: prefix, callback: callback)
    }
    
    open func enumerateKeys(callback: LevelDBKeyCallback) {
        self.enumerateKeysWith(predicate: nil, backward: false, startingAtKey: nil, andPrefix: nil, callback: callback)
    }
    
    open func enumerateKeysWith(predicate: NSPredicate?, backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, callback: LevelDBKeyCallback) {
        serialQueue.sync {
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
                        if memcmp(iKey, prefix.cString, min(prefix.count, iKeyLength)) != 0 {
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
                                callback(iKeyString, &stop)
                            }
                        }
                    } else {
                        callback(iKeyString, &stop)
                    }
                }
                if stop {
                    break
                }
                backward ? levelDBIteratorMoveBackward(iterator) : levelDBIteratorMoveForward(iterator)
            }
            levelDBIteratorDelete(iterator)
        }
    }
    
	open func enumerateKeysAndDictionaries(backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, callback: (String, [String : Any], UnsafeMutablePointer<Bool>) -> Void) {
        enumerateKeysAndDictionariesWith(predicate: nil, backward: backward, startingAtKey: key, andPrefix: prefix, callback: callback)
    }
	
    open func enumerateKeysAndValues<T:Codable>(backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, callback: (String, T, UnsafeMutablePointer<Bool>) -> Void) {
        enumerateKeysAndValuesWith(predicate: nil, backward: backward, startingAtKey: key, andPrefix: prefix, callback: callback)
    }
    
	open func enumerateKeysAndDictionaries(callback: (String, [String : Any], UnsafeMutablePointer<Bool>) -> Void) {
        enumerateKeysAndDictionariesWith(predicate: nil, backward: false, startingAtKey: nil, andPrefix: nil, callback: callback)
    }
	
    open func enumerateKeysAndValues<T:Codable>(callback: (String, T, UnsafeMutablePointer<Bool>) -> Void) {
        enumerateKeysAndValuesWith(predicate: nil, backward: false, startingAtKey: nil, andPrefix: nil, callback: callback)
    }
    
	open func enumerateKeysAndDictionariesWith(predicate: NSPredicate?, backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, callback: (String, [String : Any], UnsafeMutablePointer<Bool>) -> Void) {
        serialQueue.sync {
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
                        if memcmp(iKey, prefix.cString, min(prefix.count, iKeyLength)) != 0 {
                            break
                        }
                    }
                    let iKeyString = String.fromCString(iKey, length: iKeyLength)
                    var iData: UnsafeMutableRawPointer? = nil
                    var iDataLength: Int = 0
                    levelDBIteratorGetValue(iterator, &iData, &iDataLength)
                    if let iData = iData, let v = dictionaryDecoder(iKeyString, Data(bytes: iData, count: iDataLength)) {
                        if predicate != nil {
                            if predicate!.evaluate(with: v) {
                                callback(iKeyString, v, &stop)
                            }
                        } else {
                            callback(iKeyString, v, &stop)
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
    }
	
    open func enumerateKeysAndValuesWith<T:Codable>(predicate: NSPredicate?, backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, callback: (String, T, UnsafeMutablePointer<Bool>) -> Void) {
        serialQueue.sync {
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
                        if memcmp(iKey, prefix.cString, min(prefix.count, iKeyLength)) != 0 {
                            break
                        }
                    }
                    let iKeyString = String.fromCString(iKey, length: iKeyLength)
                    var iData: UnsafeMutableRawPointer? = nil
                    var iDataLength: Int = 0
                    levelDBIteratorGetValue(iterator, &iData, &iDataLength)
                    if let iData = iData, let data = decoder(iKeyString, Data(bytes: iData, count: iDataLength)), let v = try? JSONDecoder().decode(T.self, from: data) {
                        if predicate != nil {
                            if predicate!.evaluate(with: v) {
                                callback(iKeyString, v, &stop)
                            }
                        } else {
                            callback(iKeyString, v, &stop)
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
    }
    
    // MARK: - Helper methods
    
    open func deleteDatabaseFromDisk() {
        self.close()
        serialQueue.sync {
            do {
                let fileManager = FileManager.default
                try fileManager.removeItem(atPath: path)
            } catch {
                NSLog("error deleting database at path \(path), \(error)")
            }
        }
    }
    
    public func open() {
        serialQueue.sync {
            self.db = levelDBOpen(path.cString)
        }
    }
    
    open func close() {
        serialQueue.sync {
            if let db = db {
                levelDBDelete(db)
                self.db = nil
            }
        }
    }
    
    open func closed() -> Bool {
        if db != nil {
            close()
        }
        return db == nil
    }
    
    // MARK: - Private functions
    
    fileprivate func _startIterator(_ iterator: UnsafeMutableRawPointer, backward: Bool, prefix: String?, start key: String?) {
        var startingKey: String
        if let prefix = prefix {
            startingKey = prefix
            if let key = key {
                if key.hasPrefix(prefix) {
                    startingKey = key
                }
            }
            let len = startingKey.count
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
                if !levelDBIteratorIsValid(iterator) {
                    levelDBIteratorMoveToFirst(iterator)
                }
            }
        } else if let key = key {
            levelDBIteratorSeek(iterator, key.cString, key.count)
        } else if backward {
            levelDBIteratorMoveToLast(iterator)
        } else {
            levelDBIteratorMoveToFirst(iterator)
        }
    }
}
