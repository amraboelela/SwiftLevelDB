//
//  Shell.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 2/11/2022.
//  Copyright © 2022 Amr Aboelela. All rights reserved.
//

import Foundation

#if os(Linux) || os(macOS)
@available(macOS 10.13, *)
public func shell(_ args: String...) throws -> String? {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = args
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    
    try task.run()
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

@available(macOS 10.13, *)
public func shellWithPipes(_ args: String...) throws -> String? {
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
        try task.run()
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
#endif

#if os(Linux)
public func reportMemory() {
    do {
        if let usage = try shellWithPipes("free -m", "grep Mem", "awk '{print $3 \"MB of \" $2 \"MB\"}'") {
            NSLog("Memory used: \(usage)")
        }
    } catch {
        NSLog("reportMemory error: \(error)")
    }
}

public func availableMemory() -> Int {
    do {
        if let avaiable = try shellWithPipes("free -m", "grep Mem", "awk '{print $7}'") {
            return Int(avaiable) ?? -1
        }
    } catch {
        NSLog("availableMemory error: \(error)")
    }
    return -1
}

public func freeMemory() -> Int {
    do {
        if let result = try shellWithPipes("free -m", "grep Mem", "awk '{print $4}'") {
            return Int(result) ?? -1
        }
    } catch {
        NSLog("freeMemory error: \(error)")
    }
    return -1
}
#elseif os(macOS)
public func getMemory() -> (Float, Float) {
    var taskInfo = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
    _ = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    let usedMb = Float(taskInfo.phys_footprint) / 1048576.0
    let totalMb = Float(ProcessInfo.processInfo.physicalMemory) / 1048576.0
    return (usedMb, totalMb)
}

public func reportMemory() {
    let (usedMb, totalMb) = getMemory()
    print("Memory used MB: \(usedMb) of \(totalMb)")
}

public func availableMemory() -> Int {
    let (usedMb, totalMb) = getMemory()
    return Int(totalMb - usedMb)
}

public func freeMemory() -> Int {
    let (usedMb, totalMb) = getMemory()
    return Int(totalMb - usedMb)
}
#endif
