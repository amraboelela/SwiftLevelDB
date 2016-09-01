//
//  Data.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 9/1/16.
//  Copyright © 2016 Amr Aboelela. All rights reserved.
//
//  See LICENCE for details.
//

import Foundation

#if swift(>=3.0)
    public let stringEncoding = String.Encoding.utf8
#else
    public let stringEncoding = NSUTF8StringEncoding
#endif

extension Data {

    public var simpleDescription : String {
        if let result = String(data: self, encoding: stringEncoding) {
            return result
        } else {
            return ""
        }
    }

}
