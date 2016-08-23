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

typealias LevelDBKeyBlock = (String, UnsafeMutablePointer<Bool>) -> Void
typealias LevelDBKeyValueBlock = (String, AnyObject, UnsafeMutablePointer<Bool>) -> Void
typealias LevelDBLazyKeyValueBlock = (String, () -> AnyObject, UnsafeMutablePointer<Bool>) -> Void

class LevelDB {
    
    var name: String
    var path: String
    var encoder: (String, AnyObject) -> NSData
    var decoder: (String, NSData) -> AnyObject
    var db: UnsafeMutablePointer<Void>?
    
    // MARK: - Life cycle
    
    required init(path: String, name: String) {
        self.name = name
        self.path = path
        self.encoder = {(key: String, object: AnyObject) -> NSData in
            #if DEBUG
                var onceToken: dispatch_once_t
                dispatch_once(onceToken, {() -> Void in
                    print("No encoder block was set for this database [\(name)]")
                    print("Using a convenience encoder/decoder pair using NSKeyedArchiver.")
                })
            #endif
            return NSKeyedArchiver.archivedDataWithRootObject(object)
        }
        self.decoder = {(key: String, data: NSData) -> AnyObject in
            return NSKeyedUnarchiver.unarchiveObjectWithData(data)!
        }
        let dirpath = path.stringByDeletingLastPathComponent()
        let fm = NSFileManager.defaultManager()
        do {
            try fm.createDirectoryAtPath(dirpath, withIntermediateDirectories:true, attributes:nil)
        }
        catch let error {
            print("Problem creating parent directory: \(error)")
            return
        }
        self.db = levelDBOpen(path.cString)
    }
    
    // MARK: - Class methods
    
    class func databaseInLibraryWithName(_ name: String) -> AnyObject {
        let path = NSURL(fileURLWithPath:getLibraryPath()).URLByAppendingPathComponent(name).absoluteString
        return self.init(path:path, name:name)
    }
    
    class func getLibraryPath() -> String {
        var paths = NSSearchPathForDirectoriesInDomains(.LibraryDirectory, .UserDomainMask, true)
        return paths[0]
    }
    
    
    // MARK: - Accessors
    
    func description() -> String {
        return "<LevelDB:\(self) path: \(path)>"
    }
    
    func setObject(_ value:AnyObject?, forKey key:String) {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return
        }
        if let newValue = value {
            let data = encoder(key, newValue)
            let status = levelDBItemPut(db, key.cString, key.length, data.mutableBytes, data.length)
            if status != 0 {
                print("Problem storing key/value pair in database")
            }
        } else {
            levelDBItemDelete(db, key.cString, key.length)
        }
    }
    
    subscript(key: String) -> AnyObject? {
        get {
            // return an appropriate subscript value here
            return objectForKey(key)
        }
        set(newValue) {
            // perform a suitable setting action here
            setObject(newValue, forKey: key)
        }
    }
    
    func addEntriesFromDictionary(dictionary: [String : AnyObject]) {
        for (key, value) in dictionary {
            self[key] = value
        }
    }
    
    func objectForKey(_ key: String) -> AnyObject? {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return nil
        }
        let rawData: UnsafeMutablePointer<UnsafeMutablePointer<Void>> = nil
        let rawDataLength: UnsafeMutablePointer<Int> = nil
        let status = levelDBItemGet(db, key.cString, key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), rawData, rawDataLength)
        if status != 0 {
            return nil
        }
        let data = NSData(bytes: rawData[0], length: rawDataLength[0])
        return decoder(key, data)
    }
    
    func objectsForKeys(_ keys: [String]) -> [AnyObject?] {
        var result = [AnyObject?](count: keys.count, repeatedValue: nil)
        var index = 0
        for key in keys {
            result[index] = self[key]
            index += 1
        }
        return result
    }
    
    func objectExistsForKey(_ key: String) -> Bool {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return false
        }
        let rawData: UnsafeMutablePointer<UnsafeMutablePointer<Void>> = nil
        let rawDataLength: UnsafeMutablePointer<Int> = nil
        let status = levelDBItemGet(db, key.cString, key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), rawData, rawDataLength)
        if status == 0 {
            return true
        } else {
            return false
        }
    }
    
    func removeObjectForKey(_ key: String) {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return
        }
        let status = levelDBItemDelete(db, key.cString, key.length)
        if status != 0 {
            print("Problem removing object with key: \(key) in database")
        }
    }
    
    func removeObjectsForKeys(_ keys: [String]) {
        for key in keys {
            removeObjectForKey(key)
        }
    }
    
    func removeAllObjects() {
        self.removeAllObjectsWithPrefix("")
    }
    
    func removeAllObjectsWithPrefix(_ prefix: String) {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return
        }
        let iterator = levelDBIteratorNew(db)
        let prefixPtr = prefix.cString
        let prefixLen = prefix.length
        
        if prefix.length > 0 {
            levelDBIteratorSeek(iterator, prefix.cString, prefix.length)
        } else {
            levelDBIteratorMoveToFirst(iterator)
        }
        while levelDBIteratorIsValid(iterator) {
            let iKey: UnsafeMutablePointer<UnsafeMutablePointer<Int8>> = nil
            let iKeyLength: UnsafeMutablePointer<Int> = nil
            levelDBIteratorGetKey(iterator, iKey, iKeyLength)
            if prefix.length > 0 && memcmp(iKey[0], prefixPtr, min(prefixLen, iKeyLength[0])) != 0 {
                break;
            }
            levelDBItemDelete(db, iKey[0], iKeyLength[0])
            levelDBIteratorMoveForward(iterator)
        }
        levelDBIteratorDelete(iterator)
    }
    
    func allKeys() -> [String] {
        var keys = [String]()
        self.enumerateKeysUsingBlock({key, stop in
            keys.append(key)
        })
        return keys
    }
    
    func keysByFilteringWithPredicate(_ predicate: NSPredicate) -> [String] {
        var keys = [String]()
        enumerateKeysAndObjectsWithPredicate(predicate, backward: false, startingAtKey: nil, andPrefix: nil, usingBlock: {key, obj, stop in
            keys.append(key)
        })
        return keys
    }
    
    func dictionaryByFilteringWithPredicate(_ predicate: NSPredicate) -> [NSObject : AnyObject] {
        var results = [NSObject : AnyObject]()
        
        enumerateKeysAndObjectsWithPredicate(predicate, backward: false, startingAtKey: nil, andPrefix: nil, usingBlock: {key, obj, stop in
            results[key] = obj
        })
        return results
    }
    
    func _startIterator(_ iterator: UnsafeMutablePointer<Void>, backward: Bool, prefix: String?, start key: String?) {
        var startingKey: String
        //if let prefix = prefix {
        if let prefix = prefix {
            startingKey = prefix
            if let key = key {
                if let range = key.rangeOfString(prefix) {
                    if range.startIndex == key.startIndex && range.count > 0 {
                        startingKey = key
                    }
                }
            }
            let len = startingKey.length
            // If a prefix is provided and the iteration is backwards
            // we need to start on the next key (maybe discarding the first iteration)
            if backward {
                var i: Int = len - 1
                //var startingKeyCopy = startingKey
                let startingKeyPtr = UnsafeMutablePointer<Int8>(malloc(len))
                memcpy(startingKeyPtr, startingKey.cString, len)
                var keyChar: UnsafeMutablePointer<Int8> = startingKeyPtr
                while true {
                    if i < 0 {
                        levelDBIteratorMoveToLast(iterator)
                        break
                    }
                    keyChar += i
                    if keyChar[0] < 255 {
                        keyChar[0] += 1
                        levelDBIteratorSeek(iterator, startingKeyPtr, len)
                        if levelDBIteratorIsValid(iterator) {
                            levelDBIteratorMoveToLast(iterator)
                        }
                    }
                    i -= 1
                }
                free(startingKeyPtr)
                if levelDBIteratorIsValid(iterator) {
                    return
                }
                
                let iKey: UnsafeMutablePointer<UnsafeMutablePointer<Int8>> = nil
                let iKeyLength: UnsafeMutablePointer<Int> = nil
                levelDBIteratorGetKey(iterator, iKey, iKeyLength)
                
                if len > 0 {
                    let cmp = memcmp(iKey, startingKey.cString, len)
                    if cmp > 0 {
                        levelDBIteratorMoveBackward(iterator)
                    }
                }
            } else {
                // Otherwise, we start at the provided prefix
                levelDBIteratorSeek(iterator, startingKey.cString, len)
            }
            //}
        } else if let key = key {
            levelDBIteratorSeek(iterator, key.cString, key.length)
        } else if backward {
            levelDBIteratorMoveToLast(iterator)
        } else {
            levelDBIteratorMoveToFirst(iterator)
        }
        
    }
    
    func enumerateKeysUsingBlock(_ block: LevelDBKeyBlock) {
        self.enumerateKeysBackward(false, startingAtKey: nil, filteredByPredicate: nil, andPrefix: nil, usingBlock: block)
    }
    
    func enumerateKeysBackward(_ backward: Bool, startingAtKey key: String?, filteredByPredicate predicate: NSPredicate?, andPrefix prefix: String?, usingBlock block: LevelDBKeyBlock) {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return
        }
        let iterator = levelDBIteratorNew(db)
        var stop = false
        var iterate : LevelDBKeyValueBlock
        if let predicate = predicate {
            iterate = {key, value, stop in
                if predicate.evaluateWithObject(value) {
                    block(key, stop)
                }
            }
        } else {
            iterate = {key, value, stop in
                block(key, stop)
            }
        }
        _startIterator(iterator, backward: backward, prefix: prefix, start: key)
        while levelDBIteratorIsValid(iterator) {
            
            let iKey: UnsafeMutablePointer<UnsafeMutablePointer<Int8>> = nil
            let iKeyLength: UnsafeMutablePointer<Int> = nil
            levelDBIteratorGetKey(iterator, iKey, iKeyLength)
            
            if let prefix = prefix {
                if memcmp(iKey, prefix.cString, min(prefix.length, iKeyLength[0])) != 0 {
                    break
                }
            }
            let iKeyString = String(bytes: iKey, length: iKeyLength, encoding: NSUTF8StringEncoding)
            
            let iData: UnsafeMutablePointer<UnsafeMutablePointer<Void>> = nil
            let iDataLength: UnsafeMutablePointer<Int> = nil
            levelDBIteratorGetValue(iterator, iData, iDataLength)
            let v : AnyObject? = (predicate == nil) ? nil : decoder(iKeyString, NSData(bytes: iData[0], length: iDataLength[0]))
            iterate(iKeyString, v!, &stop)
            if stop {
                
            }
            backward ? levelDBIteratorMoveBackward(iterator) : levelDBIteratorMoveForward(iterator)
        }
        levelDBIteratorDelete(iterator)
    }
    
    func enumerateKeysAndObjectsLazily(backward backward: Bool, startingAtKey key: String?, andPrefix prefix: String?, usingBlock block:LevelDBLazyKeyValueBlock) {
        guard let db = db else {
            print("Database reference is not existent (it has probably been closed)")
            return
        }
        var iterator = levelDBIteratorNew(db)
        var stop = false
        var iterate : LevelDBLazyKeyValueBlock
        
        
        /*if let predicate = predicate {
         iterate = {key, valueGetter, stop in
         //key, valueGetter, stop in
         // We need to get the value, whether the `lazily` flag was set or not
         var value = valueGetter()
         // If the predicate yields positive, we call the block
         if predicate.evaluateWithObject(value) {
         if lazily {
         block(key, valueGetter, stop)
         } else {
         block(key, value, stop)
         }
         }
         }
         } else {*/
        //if lazily {
        //block(key, valueGetter, &stop)
        /*}
         else {
         block(key, valueGetter(), &stop)
         }*/
        //}
    }
    
    func deleteDatabaseFromDisk() {
        self.close()
        let fileManager = NSFileManager.defaultManager()
        //var error: NSError?
        do {
            try fileManager.removeItemAtPath(path)
        }
        catch {
        }
    }
    
    func close() {
        if let db = db {
            levelDBDelete(db)
            self.db = nil
        }
    }
    
    func closed() -> Bool {
        /*if let db = db {
            levelDBDelete(db)
            self.db = nil
        }*/
        return db == nil
    }
    
    /*
    func dealloc() {
        self.close()
        //name
        //path
        super.dealloc()
    }*/
    
}

/*


var iKeyString = String(bytes: iKey, length: iKeyLength, encoding: NSUTF8StringEncoding)

func id() {
    var iData
    var iDataLength: Int
    levelDBIteratorGetValue(iterator, iData!, iDataLength)
    var v = decoder(iKeyString, NSData(bytes: iData!, length: iDataLength)!)
    return v!
}

func block() {
    self.enumerateKeysAndObjectsBackward(false, lazily: false, startingAtKey: nil, filteredByPredicate: nil, andPrefix: nil, usingBlock: block)
}

*/
