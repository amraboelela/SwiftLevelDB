//
//  Shell.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 2/11/2022.
//  Copyright © 2022 Amr Aboelela. All rights reserved.
//

import Foundation

public func shell(_ args: String...) -> String? {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = args
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    
    task.launch()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: String.Encoding.utf8) {
        if output.count > 0 {
            //remove newline character.
            let lastIndex = output.index(before: output.endIndex)
            return String(output[output.startIndex ..< lastIndex])
        }
        task.waitUntilExit()
        return output
    } else {
        return nil
    }
}

public func shellWithPipes(_ args: String...) -> String? {
    var task: Process!
    var prevPipe: Pipe? = nil
    guard args.count > 0 else {
        return nil
    }
    for i in 0..<args.count {
        task = Process()
        task.launchPath = "/usr/bin/env"
        let taskArgs = args[i].components(separatedBy: " ")
        var refinedArgs = [String]()
        var refinedArg = ""
        for arg in taskArgs {
            if !refinedArg.isEmpty {
                refinedArg += " " + arg
                if arg.suffix(1) == "'" {
                    refinedArgs.append(refinedArg.replacingOccurrences(of: "\'", with: ""))
                    refinedArg = ""
                }
            } else {
                if arg.prefix(1) == "'" {
                    refinedArg = arg
                } else {
                    refinedArgs.append(arg)
                }
            }
        }
        task.arguments = refinedArgs
        
        let pipe = Pipe()
        if let prevPipe = prevPipe {
            task.standardInput = prevPipe
        }
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()
        prevPipe = pipe
    }
    if let data = prevPipe?.fileHandleForReading.readDataToEndOfFile(),
       let output = String(data: data, encoding: String.Encoding.utf8) {
        if output.count > 0 {
            //remove newline character.
            let lastIndex = output.index(before: output.endIndex)
            return String(output[output.startIndex ..< lastIndex])
        }
        task.waitUntilExit()
        return output
    }
    return nil
}

#if os(Linux)
public func reportMemory() {
    if let usage = shellWithPipes("free -m", "grep Mem", "awk '{print $3 \" of \" $2}'") {
        NSLog("Memory used MB: \(usage)")
    }
}
#elseif os(macOS)
public func reportMemory() {
    var taskInfo = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
    _ = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    let usedMb = Float(taskInfo.phys_footprint) / 1048576.0
    let totalMb = Float(ProcessInfo.processInfo.physicalMemory) / 1048576.0
    
    print("Memory used MB: \(usedMb) of \(totalMb)")
}
#endif

