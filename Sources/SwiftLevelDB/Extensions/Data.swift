//
//  Data.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 5/7/21.
//  Copyright © 2021 Amr Aboelela. All rights reserved.
//

import Foundation

extension Data {

    public func printHexEncodedString(withTag tag: String) {
        logger.log(tag + ": " + self.hexEncodedString.truncate(length:500) + " count: \(self.count)")
    }
    
    public var hexEncodedString: String {
        return map { String(format: "%02X", $0) }.joined()
    }
    
    public var simpleDescription : String {
        if let result = String(data: self, encoding: .utf8) {
            return result.truncate(length:500)
        } else {
            return String(decoding: self, as: UTF8.self).truncate(length:500)
        }
    }
}
