//
//  Logger.swift
//  TwisterFoundation
//
//  Created by Amr Aboelela on 5/6/20.
//  Copyright © 2020 Amr Aboelela. All rights reserved.
//

import Foundation

public protocol LoggerObserver {
    func log(message: String)
}

public let logger = Logger()

public class Logger {
    public var observer: LoggerObserver?

    public func log(_ message: String) {
        NSLog(message)
        if let observer = observer {
            observer.log(message: message)
        }
    }
}
