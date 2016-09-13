//
//  String.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 8/22/16.
//  Copyright © 2016 Amr Aboelela. All rights reserved.
//
//  See LICENCE for details.
//

import Foundation

extension String {
    var length: Int {
        return characters.count
    }
    
    var cString: UnsafeMutablePointer<Int8> {
        #if swift(>=3.0)        
            return UnsafeMutablePointer<Int8>(mutating: NSString(string: self).utf8String)!
        #else
            return UnsafeMutablePointer<Int8>((self as NSString).UTF8String)
        #endif
    }
    
    public static func fromCString(_ cString: UnsafeMutablePointer<Int8>) -> String {
        if let result = NSString(bytes: cString, length: Int(strlen(cString)), encoding: String.Encoding.utf8.rawValue)?._bridgeToSwift() {
            return result
        } else {
            return ""
        }
    }
}
