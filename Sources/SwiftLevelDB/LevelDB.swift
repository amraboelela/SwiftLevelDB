//
//  LevelDB.swift
//
//  Copyright 2011-2016 Pave Labs.
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

enum LevelDBError: Error {
    case initError
    case accessError
    case writingError
    case otherError
}

public actor LevelDB {
    
    public var parentPath = ""
    var name = "Database"
    var dictionaryEncoder: (String, [String : Any]) -> Data?
    var dictionaryDecoder: (String, Data) -> [String : Any]?
    var encoder: (String, Data) -> Data?
    var decoder: (String, Data) -> Data?
    public var db: UnsafeMutableRawPointer?
    
    public func setParentPath(_ parentPath: String) {
        self.parentPath = parentPath
    }
    
    public var dbPath: String {
        return parentPath + "/" + name
    }
    
    public func setEncoder(_ encoder: @escaping (String, Data) -> Data?) {
        self.encoder = encoder
    }
    
    public func setDecoder(_ decoder: @escaping (String, Data) -> Data?) {
        self.decoder = decoder
    }
    
    public func setDictionaryEncoder(_ encoder: @escaping (String, [String : Any]) -> Data?) {
        self.dictionaryEncoder = encoder
    }
    
    public func setDictionaryDecoder(_ decoder: @escaping (String, Data) -> [String : Any]?) {
        self.dictionaryDecoder = decoder
    }
    
    // MARK: - Life cycle
    
    public init(parentPath: String, name: String) {
        //NSLog("LevelDB init")
        self.parentPath = parentPath
        self.name = name
        //NSLog("LevelDB self.name: \(name)")
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
            let dirpath =  NSURL(fileURLWithPath:dbPath).deletingLastPathComponent?.path ?? ""
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
        setupCoders()
    }
    
    public convenience init(name: String) {
        self.init(parentPath: LevelDB.getLibraryPath(), name: name)
    }
    
    deinit {
        self.close()
    }
    
    func setupCoders() {
        if self.db == nil {
            //restore()
            //self.open()
            logger.log("db == nil")
        } else {
            backupIfNeeded()
        }
        self.encoder = {(key: String, value: Data) -> Data? in
            let data = value
            return data
        }
        self.decoder = {(key: String, data: Data) -> Data? in
            return data
        }
    }
    
    // MARK: - Class methods
    
    public static func getLibraryPath() -> String {
#if os(Linux)
        let paths = SearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        return paths[0]
#elseif os(macOS)
        let libraryDirectory = URL(fileURLWithPath: #file.replacingOccurrences(of: "Sources/SwiftLevelDB/LevelDB.swift", with: "Library"))
        return libraryDirectory.absoluteString.replacingOccurrences(of: "file:///", with: "/")
#else
        var libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.absoluteString.replacingOccurrences(of: "file:///", with: "/")
        libraryDirectory.removeLast()
        return libraryDirectory
#endif
    }
    
    // MARK: - Accessors
    
    public func description() -> String {
        return "<LevelDB:\(self) dbPath: \(dbPath)>"
    }
    
    public func setValue<T: Codable>(_ value: T, forKey key: String) throws {
        try self.saveValue(value, forKey: key)
    }
    
    public func save<T: Codable>(array: [(String, T)]) throws {
        let toBeSavedArray = array.sorted { $0.0 < $1.0 }
        for item in toBeSavedArray {
            try saveValue(item.1, forKey: item.0)
        }
    }
    
    public func addEntriesFromDictionary<T: Codable>(_ dictionary: [String : T]) throws {
        for (key, value) in dictionary {
            try self.setValue(value, forKey: key)
        }
    }
    
    public func value<T: Codable>(forKey key: String) -> T? {
        var result: T?
        guard let db = db else {
            NSLog("Database reference is not existent (it has probably been closed)")
            return result
        }
        var rawData: UnsafeMutableRawPointer? = nil
        var rawDataLength: Int = 0
        let status = levelDBItemGet(db, key.cString, key.count, &rawData, &rawDataLength)
        if status != 0 {
            return result
        }
        if let rawData = rawData {
            let data = Data(bytes: rawData, count: rawDataLength)
            if let decodedData = decoder(key, data) {
                result = try? JSONDecoder().decode(T.self, from: decodedData)
            }
        }
        return result
    }
    
    public func values<T: Codable>(forKeys keys: [String]) -> [T?] {
        var result = [T?]()
        for key in keys {
            result.append(self.value(forKey: key))
        }
        return result
    }
    
    public func valueExistsForKey(_ key: String) -> Bool {
        var result = false
        guard let db = db else {
            NSLog("Database reference is not existent (it has probably been closed)")
            return result
        }
        var rawData: UnsafeMutableRawPointer? = nil
        var rawDataLength: Int = 0
        let status = levelDBItemGet(db, key.cString, key.count, &rawData, &rawDataLength)
        if status == 0 {
            free(rawData)
            result = true
        }
        return result
    }
    
    public func removeValue(forKey key: String) {
        guard let db = db else {
            NSLog("Database reference is not existent (it has probably been closed)")
            return
        }
        let status = levelDBItemDelete(db, key.cString, key.count)
        if status != 0 {
            NSLog("Problem removing value with key: \(key) in database")
        }
    }
    
    public func removeValuesForKeys(_ keys: [String]) {
        for key in keys {
            removeValue(forKey: key)
        }
    }
    
    public func removeAllValues() {
        self.removeAllValuesWithPrefix("")
    }
    
    public func removeAllValuesWithPrefix(_ prefix: String) {
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
    
    public func allKeys() -> [String] {
        var keys = [String]()
        self.enumerateKeys() { key, stop in
            keys.append(key)
        }
        return keys
    }
    
    // MARK: - Enumeration
    
    public func enumerateKeys(backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, callback: LevelDBKeyCallback) {
        self.enumerateKeysWith(predicate: nil, backward: backward, startingAtKey: key, andPrefix: prefix, callback: callback)
    }
    
    public func enumerateKeys(callback: LevelDBKeyCallback) {
        self.enumerateKeysWith(predicate: nil, backward: false, startingAtKey: nil, andPrefix: nil, callback: callback)
    }
    
    public func enumerateKeysWith(predicate: NSPredicate?, backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, callback: LevelDBKeyCallback) {
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
                if let iKeyString = String(data: Data(bytes: iKey, count: iKeyLength), encoding: .utf8) {
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
                } else {
                    NSLog("Couldn't get iKeyString")
                }
            }
            if stop {
                break
            }
            backward ? levelDBIteratorMoveBackward(iterator) : levelDBIteratorMoveForward(iterator)
        }
        levelDBIteratorDelete(iterator)
    }
    
    public func enumerateKeysAndDictionaries(backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, callback: (String, [String : Any], UnsafeMutablePointer<Bool>) -> Void) {
        enumerateKeysAndDictionariesWith(predicate: nil, backward: backward, startingAtKey: key, andPrefix: prefix, callback: callback)
    }
	
    public func enumerateKeysAndValues<T:Codable>(backward: Bool, startingAtKey key: String? = nil, andPrefix prefix: String?, callback: (String, T, UnsafeMutablePointer<Bool>) -> Void) {
        enumerateKeysAndValuesWith(predicate: nil, backward: backward, startingAtKey: key, andPrefix: prefix, callback: callback)
    }
    
    public func enumerateKeysAndDictionaries(callback: (String, [String : Any], UnsafeMutablePointer<Bool>) -> Void) {
        enumerateKeysAndDictionariesWith(predicate: nil, backward: false, startingAtKey: nil, andPrefix: nil, callback: callback)
    }
	
    public func enumerateKeysAndValues<T:Codable>(callback: (String, T, UnsafeMutablePointer<Bool>) -> Void) {
        enumerateKeysAndValuesWith(predicate: nil, backward: false, startingAtKey: nil, andPrefix: nil, callback: callback)
    }
    
    public func enumerateKeysAndDictionariesWith(predicate: NSPredicate?, backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, callback: (String, [String : Any], UnsafeMutablePointer<Bool>) -> Void) {
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
                if let iKeyString = String(data: Data(bytes: iKey, count: iKeyLength), encoding: .utf8) {
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
                } else {
                    NSLog("Couldn't get iKeyString")
                }
            }
            if (stop) {
                break;
            }
            backward ? levelDBIteratorMoveBackward(iterator) : levelDBIteratorMoveForward(iterator)
        }
        levelDBIteratorDelete(iterator)
    }
	
    public func enumerateKeysAndValuesWith<T:Codable>(predicate: NSPredicate?, backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, callback: (String, T, UnsafeMutablePointer<Bool>) -> Void) {
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
                let keyData = Data(bytes: iKey, count: iKeyLength)
                let iKeyString = keyData.simpleDescription
                //String(decoding: self, as: UTF8.self)
                //if let iKeyString = String(data: Data(bytes: iKey, count: iKeyLength), encoding: .utf8) {
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
                /*} else {
                 NSLog("Couldn't get iKeyString")
                 }*/
            }
            if (stop) {
                break;
            }
            backward ? levelDBIteratorMoveBackward(iterator) : levelDBIteratorMoveForward(iterator)
        }
        levelDBIteratorDelete(iterator)
    }
    
    // MARK: - Helper methods
    
    func saveValue<T: Codable>(_ value: T, forKey key: String) throws {
        guard let db = self.db else {
            NSLog("Database reference is not existent (it has probably been closed)")
            return
        }
        let newData = try JSONEncoder().encode(value)
        var status = 0
        if let data = self.encoder(key, newData) {
            var localData = data
            localData.withUnsafeMutableBytes { (mutableBytes: UnsafeMutablePointer<UInt8>) -> () in
                status = levelDBItemPut(db, key.cString, key.count, mutableBytes, data.count)
            }
            if status != 0 {
                NSLog("setValue: Problem storing key/value pair in database, status: \(status), key: \(key), value: \(value)")
                throw LevelDBError.writingError
            }
        }
    }
    
    public func backupIfNeeded() {
        let dbBackupPath = dbPath + String(Date().dayOfWeek)
        let fileManager = FileManager.default
        let dbTempPath = dbBackupPath + ".temp"
        //logger.log("dbPath: \(dbPath)")
        try? fileManager.copyItem(atPath: self.dbPath, toPath: dbTempPath)
        try? fileManager.removeItem(atPath: dbBackupPath)
        try? fileManager.moveItem(atPath: dbTempPath, toPath: dbBackupPath)
    }
    
    public func deleteDatabaseFromDisk() throws {
        self.close()
        let fileManager = FileManager.default
        try fileManager.removeItem(atPath: dbPath)
    }
    
    public func open() {
        self.db = levelDBOpen(dbPath.cString)
    }
    
    public func close() {
        if let db = db {
            levelDBDelete(db)
            self.db = nil
        }
    }
    
    public func closed() -> Bool {
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
