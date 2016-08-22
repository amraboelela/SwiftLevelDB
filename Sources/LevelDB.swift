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
//#define AssertDBExists(_db_) \

// MARK: - Static functions
/*func seekToFirstOrKey(iter: Void, key: String) {
    (key != nil) ? levelDBIteratorSeek(iter, key.UTF8String(), key.length) : levelDBIteratorMoveToFirst(iter)
}*/

func moveCursor(iter: UnsafeMutablePointer<Void>, backward: Bool) {
    backward ? levelDBIteratorMoveBackward(iter) : levelDBIteratorMoveForward(iter)
}

// MARK: - Public functions
func getLibraryPath() -> String {
    var paths = NSSearchPathForDirectoriesInDomains(.LibraryDirectory, .UserDomainMask, true)
    return paths[0]
}

let kLevelDBChangeType = "changeType"

let kLevelDBChangeTypePut = "put"

let kLevelDBChangeTypeDelete = "del"

let kLevelDBChangeValue = "value"

let kLevelDBChangeKey = "key"
/*
LevelDBOptions MakeLevelDBOptions() {
    return (LevelDBOptions) {true, true, false, false, true, 0, 0};
}
 
@interface LevelDB()

@end
*/
class LevelDB {

  /*  init(path: String, name: String) {
        super.init()
        do {
            
                self.name = name
                self.path = path
                var dirpath = path.stringByDeletingLastPathComponent()
                var fm = NSFileManager.defaultManager()
                var crError: NSError?
                var success = (try fm!.createDirectoryAtPath(dirpath, withIntermediateDirectories: true, attributes: nil))
                if success {
                    print("Problem creating parent directory: \(crError!)")
                    return nil
                }
                self.db = levelDBOpen(path.UTF8String())
                self.encoder = {(key: String, object: AnyObject) -> NSData in
        #if DEBUG
                    var onceToken: dispatch_once_t
                    dispatch_once(onceToken, {() -> Void in
                        print("No encoder block was set for this database [\(name)]")
                        print("Using a convenience encoder/decoder pair using NSKeyedArchiver.")
                    })
        #endif
                    return NSKeyedArchiver.archivedDataWithRootObject(object!)
                }
                self.decoder = {(key: String, data: NSData) -> id in
                    return NSKeyedUnarchiver.unarchiveObjectWithData(data)
                }
            
        }
        catch let error {
        }
    }

    class func databaseInLibraryWithName(name: String) -> AnyObject {
        var path = NSURL(fileURLWithPath: getLibraryPath()).URLByAppendingPathComponent(name).absoluteString
        var ldb = self.init(path: path, name: name)
        return ldb!
    }
// MARK: - Accessors

    func description() -> String {
        return "<\(self.className()):\(self) path: \(path)>"
    }
// MARK: - Setters

    func setObject(value: AnyObject, forKey key: String) {
        AssertDBExists(db)
        NSParameterAssert(value != nil)
        var data = encoder(key, value)
        var status = levelDBItemPut(db!, key.UTF8String(), key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), data!.bytes, data!.length())
        if status != 0 {
            print("Problem storing key/value pair in database")
        }
    }

    func setObject(value: AnyObject, forKeyedSubscript key: String) {
        self[key] = value
    }

    func addEntriesFromDictionary(dictionary: [NSObject : AnyObject]) {
        dictionary.enumerateKeysAndObjectsUsingBlock({(key: AnyObject, obj: AnyObject, stop: Bool) -> Void in
            self[key] = obj
        })
    }
// MARK: - Getters

    func objectForKey(key: String) -> AnyObject {
        AssertDBExists(db)
        var outData
        var outDataLength: Int
        var status = levelDBItemGet(db!, key.UTF8String(), key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), outData!, outDataLength)
        if status != 0 {
            return nil
        }
        var data = NSData(bytes: outData!, length: outDataLength)!
        return decoder(key, data!)
    }

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
        AssertDBExists(db)
        var outData
        var outDataLength: Int
        var status = levelDBItemGet(db!, key.UTF8String(), key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), outData!, outDataLength)
        if status != 0 {
            return false
        }
        else {
            return true
        }
    }
// MARK: - Removers

    func removeObjectForKey(key: String) {
        AssertDBExists(db)
        var status = levelDBItemDelete(db!, key.UTF8String(), key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
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
        AssertDBExists(db)
        var iter = levelDBIteratorNew(db!)
        let prefixPtr = prefix.UTF8String()
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
                memcpy(startingKeyPtr, startingKey.UTF8String(), len)
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
                    var cmp = memcmp(iKey, startingKey.UTF8String(), len)
                    if cmp > 0 {
                        levelDBIteratorMoveBackward(iter)
                    }
                }
            }
            else {
                // Otherwise, we start at the provided prefix
                levelDBIteratorSeek(iter!, startingKey.UTF8String(), len)
            }
        }
        else if key != "" {
            levelDBIteratorSeek(iter!, key.UTF8String(), key.length)
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
        AssertDBExists(db)
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
            if prefix && memcmp(iKey, prefix.UTF8String(), min((prefix.length as! size_t), iKeyLength)) != 0 {

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
        AssertDBExists(db)
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