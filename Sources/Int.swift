//
//  Int.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 8/31/16.
//  Copyright © 2016 Amr Aboelela. All rights reserved.
//
//  See LICENCE for details.
//

import Foundation

extension Int {

    public static func fromNSNumber(_ aNumber: NSNumber?) -> Int {
        if let aNumber = aNumber {
            return Int(aNumber)
        } else {
            return 0
        }
    }

    public static func fromNSObject(_ anObject: NSObject) -> Int {
        return fromNSNumber(anObject as? NSNumber)
    }
}
