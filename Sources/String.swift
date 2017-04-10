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

public extension String {
    var length: Int {
        return characters.count
    }
    
    public var cString: UnsafeMutablePointer<Int8> {
        return UnsafeMutablePointer<Int8>(mutating: NSString(string: self).utf8String)!
    }
    
    public static func fromCString(_ cString: UnsafeRawPointer, length: Int) -> String {
        #if os(Linux) 
            if let result =  NSString(bytes: cString, length: length, encoding: String.Encoding.utf8.rawValue)?._bridgeToSwift() {
                return result
            } else {
                return ""
            }
        #else
            return NSString(bytes: cString, length: length, encoding: String.Encoding.utf8.rawValue)! as String;
        #endif
   }
}

func DLog(message: String, filename: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
        NSLog("[\((filename as NSString).lastPathComponent):\(line)] \(function) - \(message)")
    #endif
}

func ALog(message: String, filename: String = #file, function: String = #function, line: Int = #line) {
    NSLog("%@","[\((filename as NSString).lastPathComponent):\(line)] \(function) - \(message)")
}
