//
//  NSData.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 8/22/16.
//  Copyright © 2016 Amr Aboelela. All rights reserved.
//

import Foundation

extension NSData {
    var mutableBytes: UnsafeMutablePointer<Void> {
        return UnsafeMutablePointer<Void>(self.bytes)
    }
}