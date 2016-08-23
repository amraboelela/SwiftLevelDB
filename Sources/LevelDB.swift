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

    class func databaseInLibraryWithName(_ name: String) -> AnyObject {
        let path = NSURL(fileURLWithPath:getLibraryPath()).URLByAppendingPathComponent(name).absoluteString
        return self.init(path:path, name:name)
    }

    // MARK: - Class methods
    
    /*class func AssertDBExists(_ db: UnsafeMutablePointer<Void>?) {
        assert(db != nil, "Database reference is not existent (it has probably been closed)");
    }*/
    
    class func seekToFirstOrKey(_ iter: UnsafeMutablePointer<Void>, _ key: String?) {
        if let theKey = key {
            levelDBIteratorSeek(iter, theKey.cString, theKey.length)
        } else {
            levelDBIteratorMoveToFirst(iter)
        }
    }
    
    class func moveCursor(_ iter: UnsafeMutablePointer<Void>, _ backward: Bool) {
        backward ? levelDBIteratorMoveBackward(iter) : levelDBIteratorMoveForward(iter)
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
        let outData: UnsafeMutablePointer<UnsafeMutablePointer<Void>> = nil
        let outDataLength: UnsafeMutablePointer<Int> = nil
        let status = levelDBItemGet(db, key.cString, key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), outData, outDataLength)
        if status != 0 {
            return nil
        }
        let data = NSData(bytes: outData[0], length: outDataLength[0])
        return decoder(key, data)
    }

    /*
    func objectForKeyedSubscript(key: AnyObject) -> AnyObject {
        return (self[key] as! String)
    }

    func objectsForKeys(keys: [AnyObject], notFoundMarker marker: AnyObject) -> AnyObject {
        var result = [AnyObject](minimumCapacity: keys.count)
        keys.enumerateObjectsUsingBlock({(objId: AnyObject, idx: Int, stop: Bool) -> Void in
            var object = (self[objId] as! AnyObject)
            if object == nil {
                object = marker!
            }
            result.insert(object!, atIndex: idx)
        })
        return [AnyObject](result)
    }

    func objectExistsForKey(key: String) -> Bool {
     guard let db = db else {
     print("Database reference is not existent (it has probably been closed)")
     return
     }
        var outData
        var outDataLength: Int
        var status = levelDBItemGet(db!, key.cString, key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), outData!, outDataLength)
        if status != 0 {
            return false
        }
        else {
            return true
        }
    }
// MARK: - Removers

    func removeObjectForKey(key: String) {
     guard let db = db else {
     print("Database reference is not existent (it has probably been closed)")
     return
     }
        var status = levelDBItemDelete(db!, key.cString, key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        if status != 0 {
            print("Problem removing object with key: \(key) in database")
        }
    }

    func removeObjectsForKeys(keyArray: [AnyObject]) {
        keyArray.enumerateObjectsUsingBlock({(obj: AnyObject, idx: Int, stop: Bool) -> Void in
            self.removeObjectForKey(obj)
        })
    }

    func removeAllObjects() {
        self.removeAllObjectsWithPrefix(nil)
    }

    func removeAllObjectsWithPrefix(prefix: String) {
     guard let db = db else {
     print("Database reference is not existent (it has probably been closed)")
     return
     }
        var iter = levelDBIteratorNew(db!)
        let prefixPtr = prefix.cString
        var prefixLen = prefix.length
        seekToFirstOrKey(iter!, prefix)
        while levelDBIteratorIsValid(iter!) {
            var iKey: [Character]
            var iKeyLength: Int
            levelDBIteratorGetKey(iter!, iKey, iKeyLength)
            if prefix && memcmp(iKey, prefixPtr!, min(prefixLen, iKeyLength)) != 0 {

            }
            levelDBItemDelete(db!, iKey, iKeyLength)
            levelDBIteratorMoveForward(iter!)
        }
        levelDBIteratorDelete(iter!)
    }
// MARK: - Selection

    func allKeys() -> [AnyObject] {
        var keys = [AnyObject]()
        self.enumerateKeysUsingBlock({(key: String, stop: Bool) -> Void in
            keys.append(key)
        })
        return [AnyObject](keys)
    }

    func keysByFilteringWithPredicate(predicate: NSPredicate) -> [AnyObject] {
        var keys = [AnyObject]()
        self.enumerateKeysAndObjectsBackward(false, lazily: false, startingAtKey: nil, filteredByPredicate: predicate!, andPrefix: nil, usingBlock: {(key: String, obj: AnyObject, stop: Bool) -> Void in
            keys.append(key)
        })
        return [AnyObject](keys)
    }

    func dictionaryByFilteringWithPredicate(predicate: NSPredicate) -> [NSObject : AnyObject] {
        var results = [NSObject : AnyObject]()
        self.enumerateKeysAndObjectsBackward(false, lazily: false, startingAtKey: nil, filteredByPredicate: predicate!, andPrefix: nil, usingBlock: {(key: String, obj: AnyObject, stop: Bool) -> Void in
            results[key] = obj
        })
        return [NSObject : AnyObject](dictionary: results)
    }
// MARK: - Enumeration

    func _startIterator(iter: UnsafeMutablePointer<Void>, backward: Bool, prefix: String, start key: String) {
        let prefixPtr
        var prefixLen: size_t
        var startingKey: String
        if prefix != "" {
            startingKey = prefix
            if key != "" {
                var range = key.rangeOfString(prefix)
                if range.length > 0 && range.location == 0 {
                    startingKey = key
                }
            }
            var len = startingKey.length
            // If a prefix is provided and the iteration is backwards
            // we need to start on the next key (maybe discarding the first iteration)
            if backward {
                var i: Int64 = len - 1
                var startingKeyPtr = malloc(len)
                memcpy(startingKeyPtr, startingKey.cString, len)
                var keyChar: [UInt8]
                while 1 {
                    if i < 0 {
                        levelDBIteratorMoveToLast(iter)
                    }
                    keyChar = UInt8(startingKeyPtr) + i
                    if keyChar < 255 {
                        keyChar = keyChar + 1
                        levelDBIteratorSeek(iter!, startingKeyPtr, len)
                        if levelDBIteratorIsValid(iter!) {
                            levelDBIteratorMoveToLast(iter)
                        }
                    }
                    i -= 1
                }
                free(startingKeyPtr)
                if levelDBIteratorIsValid(iter!) {
                    return
                }
                var iKey: [Character]
                var iKeyLength: Int
                levelDBIteratorGetKey(iter!, iKey, iKeyLength)
                if len > 0 && prefix != nil {
                    var cmp = memcmp(iKey, startingKey.cString, len)
                    if cmp > 0 {
                        levelDBIteratorMoveBackward(iter)
                    }
                }
            }
            else {
                // Otherwise, we start at the provided prefix
                levelDBIteratorSeek(iter!, startingKey.cString, len)
            }
        }
        else if key != "" {
            levelDBIteratorSeek(iter!, key.cString, key.length)
        }
        else if backward {
            levelDBIteratorMoveToLast(iter)
        }
        else {
            levelDBIteratorMoveToFirst(iter)
        }

    }

    func enumerateKeysUsingBlock(block: LevelDBKeyBlock) {
        self.enumerateKeysBackward(false, startingAtKey: nil, filteredByPredicate: nil, andPrefix: nil, usingBlock: block)
    }

    func enumerateKeysBackward(backward: Bool, startingAtKey key: String, filteredByPredicate predicate: NSPredicate, andPrefix prefix: String, usingBlock block: LevelDBKeyBlock) {
     guard let db = db else {
     print("Database reference is not existent (it has probably been closed)")
     return
     }
        var iter = levelDBIteratorNew(db!)
        var stop = false
        var iterate = (predicate != nil) ? {(key: String, value: AnyObject, stop: Bool) -> Void in
                if predicate!.evaluateWithObject(value) {
                    block(key, stop)
                }
            } : {(key: String, value: AnyObject, stop: Bool) -> Void in
                block(key, stop)
            }
        self._startIterator(iter!, backward: backward, prefix: prefix, start: key)
        while levelDBIteratorIsValid(iter!) {
            var iKey: [Character]
            var iKeyLength: Int
            levelDBIteratorGetKey(iter!, iKey, iKeyLength)
            if prefix && memcmp(iKey, prefix.cString, min((prefix.length as! size_t), iKeyLength)) != 0 {

            }
            var iKeyString = String(bytes: iKey, length: iKeyLength, encoding: NSUTF8StringEncoding)
            var iData
            var iDataLength: Int
            levelDBIteratorGetValue(iter!, iData!, iDataLength)
            var v = (predicate == nil) ? nil : decoder(iKeyString, NSData(bytes: iData!, length: iDataLength)!)
            iterate(iKeyString, v!, stop)
            if stop {

            }
            moveCursor(iter!, backward)
        }
        levelDBIteratorDelete(iter!)
    }

    func enumerateKeysAndObjectsBackward(backward: Bool, lazily: Bool, startingAtKey key: String, filteredByPredicate predicate: NSPredicate, andPrefix prefix: String, usingBlock block: AnyObject) {
     guard let db = db else {
     print("Database reference is not existent (it has probably been closed)")
     return
     }
        var iter = levelDBIteratorNew(db!)
        var stop = false
        var iterate = (predicate != nil) ? {(key: String, valueGetter: LevelDBValueGetterBlock, stop: Bool) -> Void in
                    // We need to get the value, whether the `lazily` flag was set or not
                var value = valueGetter()
                // If the predicate yields positive, we call the block
                if predicate!.evaluateWithObject(value!) {
                    if lazily {
                        (block as! LevelDBLazyKeyValueBlock)(key, valueGetter, stop)
                    }
                    else {
                        (block as! LevelDBKeyValueBlock)(key, value!, stop)
                    }
                }
            } : {(key: String, valueGetter: LevelDBValueGetterBlock, stop: Bool) -> Void in
                if lazily {
                    (block as! LevelDBLazyKeyValueBlock)(key, valueGetter, stop)
                }
                else {
                    (block as! LevelDBKeyValueBlock)(key, valueGetter(), stop)
                }
            }
    }*/

}

/*levelDBIteratorIsValid(iter)

var iKey = [Character]()

var iKeyLength = 0

MIN(())

var iKeyString = String(bytes: iKey, length: iKeyLength, encoding: NSUTF8StringEncoding)

func id() {
    var iData
    var iDataLength: Int
    levelDBIteratorGetValue(iter!, iData!, iDataLength)
    var v = decoder(iKeyString, NSData(bytes: iData!, length: iDataLength)!)
    return v!
}

levelDBIteratorDelete(iter)

func block() {
    self.enumerateKeysAndObjectsBackward(false, lazily: false, startingAtKey: nil, filteredByPredicate: nil, andPrefix: nil, usingBlock: block)
}

func deleteDatabaseFromDisk() {
    self.close()
    var fileManager = NSFileManager.defaultManager()
    var error: NSError?
    do {
        try fileManager!.removeItemAtPath(path)
    }
    catch let error {
    }
}

func close() {
    if db != nil {
        levelDBDelete(db)
        self.db = nil
    }
}

func closed() {
    return db == nil
}

func dealloc() {
    self.close()
    name
    path
    super.dealloc()
}*/