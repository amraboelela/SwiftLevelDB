//
//  NSObject.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 9/1/16.
//  Copyright © 2016 Amr Aboelela. All rights reserved.
//
//  See LICENCE for details.
//

import Foundation

#if swift(>=3.0)
#else
    //public typealias AnyHashable = AnyObject
#endif

extension NSObject {

    public static func fromAny(_ anObject: Any?) -> NSObject? {
        if let aDictionary = anObject as? [String : Any] {
            return aDictionary._bridgeToObjectiveC() 
        } else if let anArray = anObject as? [Any] {
            return anArray._bridgeToObjectiveC() 
        } else if let aString = anObject as? String {
            return aString._bridgeToObjectiveC()
        } else if let anInt = anObject as? Int {
            return anInt._bridgeToObjectiveC()
        }
        return nil
    }

    /*
    public static func toAny(_ anObject: NSObject?) -> Any? {
        guard let anObject = anObject else {
            return nil
        }
        if let aDictionary = anObject as? NSDictionary {
            return aDictionary._bridgeToSwift()
        } else if let anArray = anObject as? NSArray {
            return anArray._bridgeToSwift()
        } else if let aString = anObject as? NSString {
            return aString._bridgeToSwift()
        }
        return nil
    }*/
}
