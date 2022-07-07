//
//  Data.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 5/7/21.
//  Copyright © 2021 Amr Aboelela. All rights reserved.
//

import CoreFoundation
import Foundation

extension Data {

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
    
    public static func reportMemory() {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let usedMb = Float(taskInfo.phys_footprint) / 1048576.0
        let totalMb = Float(ProcessInfo.processInfo.physicalMemory) / 1048576.0
        result != KERN_SUCCESS ? print("Memory used: ? of \(totalMb)") : print("Memory used: \(usedMb) of \(totalMb)")
    }
    
    /*
    public static func reportMemory() {
        var info = mach_task_basic_info()
        let MACH_TASK_BASIC_INFO_COUNT = MemoryLayout<mach_task_basic_info>.stride/MemoryLayout<natural_t>.stride
        var count = mach_msg_type_number_t(MACH_TASK_BASIC_INFO_COUNT)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: MACH_TASK_BASIC_INFO_COUNT) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }
        if kerr == KERN_SUCCESS {
            print("Memory in use (in bytes): \(info.resident_size)")
        } else {
            print("Error with task_info(): " +
                (String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))
        }
    }*/
}
