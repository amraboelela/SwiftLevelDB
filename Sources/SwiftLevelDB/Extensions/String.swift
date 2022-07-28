//
//  String.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 7/31/18.
//  Copyright © 2018 Amr Aboelela. All rights reserved.
//
//  See LICENCE for details.
//

import Foundation

public extension String {
    static let characters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
    static let hashtagCharacters = characters.union(CharacterSet(charactersIn: "#"))
    static let mentionCharacters = characters.union(CharacterSet(charactersIn: "@"))
    
    // MARK: - Accessors
    
    var dataFromHexadecimal: Data {
        var hex = self
        var data = Data()
        while(hex.count > 0) {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            //logger.log("dataFromHexadecimal hex: \(hex)")
            var ch: UInt32 = 0
            if Scanner(string: c).scanHexInt32(&ch) {
                var char = UInt8(ch)
                data.append(&char, count: 1)
            }
        }
        return data
    }
    
    var isVacant: Bool {
        return trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var cString: UnsafeMutablePointer<Int8> {
        return UnsafeMutablePointer<Int8>(mutating: NSString(string: self).utf8String)!
    }
    
    var hashtags: [String] {
        var result = Set<String>()

        let words = self.lowercased().components(separatedBy: String.hashtagCharacters.inverted)
        // tag each word if it has a hashtag
        for word in words {
            if word.count < 3 {
                continue
            }
            // found a word that is prepended by a hashtag!
            if word.hasPrefix("#") {
                // drop the hashtag
                let stringifiedWord = word.dropFirst()
                if let firstChar = stringifiedWord.unicodeScalars.first, NSCharacterSet.decimalDigits.contains(firstChar) {
                    // hashtag contains a number, like "#1"
                    // so don't add it
                } else {
                    result.insert(word)
                }
            }
        }
        return Array(result)
    }

    var mentions: [String] {
        var result = Set<String>()
        let words = self.lowercased().components(separatedBy: String.mentionCharacters.inverted)
        for word in words {
            if word.hasPrefix("@") {
                result.insert(word)
            }
        }
        return Array(result)
    }

    func truncate(length: Int, trailing: String = "…") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        } else {
            return self
        }
    }
    
}

func DLog(_ message: String, filename: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
        logger.log("[\(NSString(string: filename).lastPathComponent):\(line)] \(function) - \(message)")
    #endif
}

func ALog(_ message: String, filename: String = #file, function: String = #function, line: Int = #line) {
    logger.log("[\(NSString(string: filename).lastPathComponent):\(line)] \(function) - \(message)")
}
