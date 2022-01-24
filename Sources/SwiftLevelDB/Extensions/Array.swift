//
//  Array.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 4/25/18.
//  Copyright © 2018 Amr Aboelela. All rights reserved.
//

import Foundation

extension Array where Element: Equatable {
    
    // Remove first collection element that is equal to the given `object`:
    mutating public func remove(object: Element) {
        if let index = firstIndex(of: object) {
            remove(at: index)
        }
    }
}
