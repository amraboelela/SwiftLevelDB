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
    
    public var dataWithHexString: Data {
        var hex = self
        var data = Data()
        while(hex.count > 0) {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            var ch: UInt32 = 0
            Scanner(string: c).scanHexInt32(&ch)
            var char = UInt8(ch)
            data.append(&char, count: 1)
        }
        return data
    }
    
}

func DLog(_ message: String, filename: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
        NSLog("[\(NSString(string: filename).lastPathComponent):\(line)] \(function) - \(message)")
    #endif
}

func ALog(_ message: String, filename: String = #file, function: String = #function, line: Int = #line) {
    NSLog("[\(NSString(string: filename).lastPathComponent):\(line)] \(function) - \(message)")
}