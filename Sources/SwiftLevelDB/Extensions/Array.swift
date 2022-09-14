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
    
    public func asyncCompactMap<Element2>(closure: (Element) async -> Element2?) async -> [Element2] {
        var result = [Element2]()
        for item in self {
            if let item2 = await closure(item) {
                result.append(item2)
            }
        }
        return result
    }
    
    // MARK: - Sorting
    /*
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
    
    public mutating func quickSort(closure: (Element, Element) async -> Bool) async -> Void {
        await quickSort(&self[...], closure: closure)
    }
    
    private func quickSort(_ array: inout ArraySlice<Element>, closure: (Element, Element) async -> Bool) async {
        if array.count < 2 {
            return
        }
        
        await sortPivot(in: &array, closure: closure)
        let pivot = await partition(&array, closure: closure)
        
        await quickSort(&array[array.startIndex..<pivot], closure: closure)
        await quickSort(&array[pivot + 1..<array.endIndex], closure: closure)
    }
    
    private func partition(_ array: inout ArraySlice<Element>, closure: (Element, Element) async -> Bool) async -> ArraySlice<Element>.Index {
        let midPoint = (array.startIndex + array.endIndex) / 2
        array.swapAt(midPoint, array.startIndex)
        let pivot = array[array.startIndex]
        
        var lower = array.startIndex
        var upper = array.endIndex - 1
        
        repeat {
            while (await closure(array[lower], pivot) || array[lower] == pivot)
                    && lower < array.endIndex - 1 {
                lower += 1
            }
            while await closure(pivot, array[upper]) || pivot == array[upper] {
                upper -= 1
            }
            
            if lower < upper {
                array.swapAt(lower, upper)
            }
        } while lower < upper
        
        array.swapAt(array.startIndex, upper)
        return upper
    }
    
    private func sortPivot(in array: inout ArraySlice<Element>, closure: (Element, Element) async -> Bool) async {
        let startPoint = array.startIndex
        let midPoint = (array.startIndex + array.endIndex) / 2
        let endPoint = array.endIndex - 1
        
        if await closure(array[midPoint], array[startPoint]) {
            array.swapAt(startPoint, midPoint)
        }
        if await closure(array[endPoint], array[midPoint]) {
            array.swapAt(midPoint, endPoint)
        }
        if await closure(array[midPoint], array[startPoint]) {
            array.swapAt(startPoint, midPoint)
        }
    }*/
}
