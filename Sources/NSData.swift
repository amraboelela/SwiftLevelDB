//
//  NSData.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 8/22/16.
//  Copyright © 2016 Amr Aboelela. All rights reserved.
//

import Foundation

extension NSData {
    
    #if !swift(>=3.0)
    var mutableBytes: UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(self.bytes)
    }
    #endif
}
