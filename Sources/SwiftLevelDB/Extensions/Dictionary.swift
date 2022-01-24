//
//  Dictionary.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 2/26/18.
//  Copyright © 2018 Amr Aboelela. All rights reserved.
//
//

import Foundation

extension Dictionary {
    
    mutating func update(withDictionary dictionary:Dictionary) {
        for (key,value) in dictionary {
            self.updateValue(value, forKey:key)
        }
    }
}
