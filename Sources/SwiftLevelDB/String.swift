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
    
    public var dataFromHexadecimal: Data? {
        var data = Data(capacity: self.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSMakeRange(0, utf16.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else { return nil }
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
