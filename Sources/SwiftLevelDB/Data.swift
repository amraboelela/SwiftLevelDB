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

extension Data {

    public var simpleDescription : String {
        if let result = String(data: self, encoding: String.Encoding.utf8) {
            return result
        } else {
            return ""
        }
    }

}