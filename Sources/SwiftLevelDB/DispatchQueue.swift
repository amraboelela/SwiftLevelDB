//
//  DispatchQueue.swift
//  TwisterFoundation
//
//  Created by Amr Aboelela on 2/12/17.
//  Copyright © 2017 Amr Aboelela. All rights reserved.
//
//

import Foundation
import Dispatch

extension DispatchQueue {
    
    static var currentQueueName: String? {
        #if os(Linux)
        return ""
        #else
        let name = __dispatch_queue_get_label(nil)
        let result = String(cString: name, encoding: .utf8)
        //logger.log("currentQueueName: result: \(result ?? "")")
        return result
        #endif
    }
    
    public func smartSync(execute closure: () -> Swift.Void) {
        #if os(Linux)
        self.sync {
            closure()
        }
        #else
        if self.label == DispatchQueue.currentQueueName {
            closure()
        } else {
            self.sync {
                closure()
            }
        }
        #endif
    }
}
