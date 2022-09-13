//
//  Array.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 4/25/18.
//  Copyright © 2018 Amr Aboelela.
//

import Foundation

extension Array where Element: Equatable {
    
    // Remove first collection element that is equal to the given `object`:
    mutating public func remove(object: Element) {
        if let index = firstIndex(of: object) {
            remove(at: index)
        }
    }
    
    public func asyncFilter(closure: (Element) async -> Bool) async -> Array {
        var result = [Element]()
        for item in self {
            if await closure(item) {
                result.append(item)
            }
        }
        return result
    }
    
    public mutating func insertionSort(closure: (Element, Element) async -> Bool) async -> Void {
        for iterationIndex in 0 ..< self.count {
            var swapIndex = iterationIndex
            while swapIndex > 0 {
                if await closure(self[swapIndex], self[swapIndex - 1]) {
                    swapAt(swapIndex, swapIndex - 1)
                    swapIndex -= 1
                } else {
                    break
                }
                
            } // end while
            
        } // end for
        
    } // end func
    
    public func asyncCompactMap<Element2>(closure: (Element) async -> Element2?) async -> [Element2] {
        var result = [Element2]()
        for item in self {
            if let item2 = await closure(item) {
                result.append(item2)
            }
        }
        return result
    }
}
