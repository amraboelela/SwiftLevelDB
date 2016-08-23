//
//  String.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 8/22/16.
//  Copyright © 2016 Amr Aboelela. All rights reserved.
//

import Foundation

extension String {
    var length: Int {
        return characters.count
    }
    
    var cString: UnsafeMutablePointer<Int8> {
        return UnsafeMutablePointer<Int8>((self as NSString).UTF8String)
    }
    
    func stringByDeletingLastPathComponent() -> String {
        return (self as NSString).stringByDeletingLastPathComponent
    }
}