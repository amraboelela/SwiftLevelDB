//
//  NSObject.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 9/1/16.
//  Copyright © 2016 Amr Aboelela.
//
//  See LICENCE for details.
//

import Foundation

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
}
