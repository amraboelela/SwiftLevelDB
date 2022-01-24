//
//  Data.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 5/7/21.
//  Copyright © 2021 Amr Aboelela. All rights reserved.
//

import Foundation
import CommonCrypto

public enum DataError: Error {
    case TerminationStatus(Int)
    case UnicodeDecodingError(Data)
    case InvalidEnvironmentVariable(String)
}
 
func FixKeyLengths(algorithm: CCAlgorithm, keyData: NSMutableData, ivData: NSMutableData) {
    let keyLength = keyData.length
    switch algorithm {
    case CCAlgorithm(kCCAlgorithmAES128):
        if keyLength <= 16 {
            keyData.length = 16
        } else if keyLength <= 24 {
            keyData.length = 24
        } else {
            keyData.length = 32
        }
    case CCAlgorithm(kCCAlgorithmDES):
        keyData.length = 8
        
    case CCAlgorithm(kCCAlgorithm3DES):
        keyData.length = 24
        
    case CCAlgorithm(kCCAlgorithmCAST):
        if keyLength <= 5 {
            keyData.length = 5
        }
        else if keyLength > 16 {
            keyData.length = 16
        }
    case CCAlgorithm(kCCAlgorithmRC4):
        if keyLength > 512 {
            keyData.length = 512
        }
    default:
        break
    }
    ivData.length = 16; //keyData.length
}

extension Data {
    public func encryptedWithSaltUsing(key: String) throws -> Data? {
        #if os(Linux)
        let ivByte = UInt8(random() % (255 + 1))
        #else
        let ivByte = UInt8(arc4random_uniform(255))
        #endif
        //print("key: " + key)
        let iv = Data([ivByte])
        var status = CCCryptorStatus(kCCSuccess)
        if let encryptedData = self.data(encrypt: true, usingAlgorithm: CCAlgorithm(kCCAlgorithmAES128), key: key, initializationVector: iv, options: CCOptions(kCCOptionPKCS7Padding), error: &status) {
            var fullEncryptedData = iv
            fullEncryptedData.append(encryptedData)
            return fullEncryptedData
        }
        throw DataError.TerminationStatus(Int(status))
    }

    public func decryptedWithSaltUsing(key: String) throws -> Data? {
        let ivPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        defer {
            ivPointer.deinitialize(count: 1)
            ivPointer.deallocate()
        }
        self.copyBytes(to: ivPointer, count: 1)
        
        let encryptedBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: self.count - 1)
        defer {
            encryptedBytes.deinitialize(count: self.count - 1)
            encryptedBytes.deallocate()
        }
        let riv = Data([ivPointer.pointee])
        //logger.log("key: \(key) riv: \(riv)")
        self.copyBytes(to: encryptedBytes, from: 1..<self.count)
        let encryptedData = Data(bytes: encryptedBytes, count: self.count - 1)
        var status = CCCryptorStatus(kCCSuccess)
        
        if let decryptedData = encryptedData.data(encrypt: false, usingAlgorithm: CCAlgorithm(kCCAlgorithmAES128), key: key, initializationVector: riv, options: CCOptions(kCCOptionPKCS7Padding), error: &status) {
            return decryptedData
        }
        throw DataError.TerminationStatus(Int(status))
    }

    func data(encrypt: Bool, usingAlgorithm algorithm: CCAlgorithm, key: String, initializationVector iv: Data, options: CCOptions, error: UnsafeMutablePointer<CCCryptorStatus>) -> Data? {
        var cryptor: CCCryptorRef? = nil
        var status = CCCryptorStatus(kCCSuccess)
        guard let keyData = key.data(using: .utf8) else {
            return nil
        }
        let keyMutableData = NSMutableData(data: keyData)
        let ivMutableData = NSMutableData(data: iv)
        FixKeyLengths(algorithm: algorithm, keyData: keyMutableData, ivData: ivMutableData)
        //Data(referencing: keyMutableData).printHexEncodedString(withTag: "keyMutableData")
        //Data(referencing: ivMutableData).printHexEncodedString(withTag: "ivMutableData")
        let operation = encrypt ? CCOperation(kCCEncrypt) : CCOperation(kCCDecrypt)
        status = CCCryptorCreate(operation, algorithm, options, keyMutableData.bytes, keyMutableData.length, ivMutableData.bytes, &cryptor)
        if status != CCCryptorStatus(kCCSuccess) {
            logger.log("CCCryptorCreate failed with code: \(status)")
            error.pointee = CCCryptorStatus(status)
            return nil
        }
        if let cryptor = cryptor {
            let result = self.runCryptor(cryptor, result: &status)
            if result == nil {
                error.pointee = CCCryptorStatus(status)
            }
            CCCryptorRelease(cryptor)
            return result
        } else {
            return nil
        }
    }
    
    func runCryptor(_ cryptor: CCCryptorRef, result status: UnsafeMutablePointer<CCCryptorStatus>) -> Data? {
        let bufsize = CCCryptorGetOutputLength(cryptor, self.count, true)
        let buf = malloc(bufsize)
        guard let buffer = buf else {
            return nil
        }
        var bufused = 0
        var bytesTotal = 0
        self.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> () in
            status.pointee = CCCryptorUpdate(cryptor, bytes, self.count, buffer, bufsize, &bufused)
        }
        if status.pointee != CCCryptorStatus(kCCSuccess) {
            logger.log("CCCryptorUpdate failed with code: \(status.pointee)")
            free(buffer)
            return nil
        }
        bytesTotal += bufused
        // From Brent Royal-Gordon (Twitter: architechies):
        //  Need to update buf ptr past used bytes when calling CCCryptorFinal()
        status.pointee = CCCryptorFinal(cryptor, buffer.advanced(by: bufused), bufsize - bufused, &bufused)
        if status.pointee != CCCryptorStatus(kCCSuccess) {
            logger.log("CCCryptorFinal failed with code: \(status.pointee)")
            free(buffer)
            return nil
        }
        bytesTotal += bufused
        return Data(bytes: buffer, count: bytesTotal)
    }

    public func printHexEncodedString(withTag tag: String) {
        logger.log(tag + ": " + self.hexEncodedString.truncate(length:500) + " count: \(self.count)")
    }
    
    public var hexEncodedString: String {
        return map { String(format: "%02X", $0) }.joined()
    }
    
    public var simpleDescription : String {
        if let result = String(data: self, encoding: .utf8) {
            return result.truncate(length:500)
        } else {
            return String(decoding: self, as: UTF8.self).truncate(length:500)
        }
    }
}
