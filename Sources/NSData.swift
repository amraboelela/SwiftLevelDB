//
//  NSData.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 8/22/16.
//  Copyright © 2016 Amr Aboelela. All rights reserved.
//

import Foundation

#if !swift(>=3.0)
    typealias UnsafeMutableRawPointer = UnsafeMutablePointer<Void>
#endif

extension NSData {
    var mutableBytes: UnsafeMutableRawPointer {
        #if swift(>=3.0)
            return UnsafeMutableRawPointer(mutating:self.bytes)
        #else
            return UnsafeMutableRawPointer(self.bytes)
        #endif
    }
}
