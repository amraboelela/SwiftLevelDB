//
//  Date.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 2/26/18.
//  Copyright © 2018 Amr Aboelela. All rights reserved.
//
//

import Foundation

extension Date {
    
    public static let oneMinute = TimeInterval(60)
    public static let oneHour = TimeInterval(60*60)
    public static let oneDay = TimeInterval(60*60*24)
    public static let thirtyDays = TimeInterval(30*24*60*60)
    public static let oneYear = TimeInterval(60*60*24*365.25)
    
    // MARK: - Accessors
    
    public static var millisecondsSinceReferenceDate: Int {
        return Int(Date.timeIntervalSinceReferenceDate * 1000)
    }
    
    public static var now: Int {
        return Int(Date().timeIntervalSince1970)
    }
    
    // MARK: - Public functions
    
    public static func timeIntervalFrom(millisecondsHex: String) -> TimeInterval {
        return Double(Int(millisecondsHex, radix: 16) ?? 0) / 1000.0
    }
    
    public static func millisecondsHexFrom(timeInterval: TimeInterval) -> String {
        let timestamp = Int(timeInterval*1000)
        let result = String(format: "%lX", timestamp)
        return result
    }
    
    public static func friendlyDateStringFrom(millisecondsHex: String) -> String {
        return friendlyDateStringFrom(timeInterval: timeIntervalFrom(millisecondsHex: millisecondsHex))
    }
    
    public static func days(numberOfDays: Int) -> TimeInterval {
        return TimeInterval(24*60*60*numberOfDays)
    }
    
    public static func friendlyDateStringFrom(epochTime: TimeInterval, locale: Locale? = nil) -> String {
        let date = Date(timeIntervalSince1970: epochTime)
        let formatter = DateFormatter()
        formatter.locale = locale ?? Locale.current
        let now = Date().timeIntervalSince1970
        
        let timeDiff = now - epochTime
        if timeDiff < Date.oneHour {
            let minutes = Int(timeDiff / Date.oneMinute)
            return "\(minutes)m"
        } else if timeDiff < Date.oneDay {
            let hours = Int(timeDiff / Date.oneHour)
            return "\(hours)h"
        } else {
            if timeDiff < Date.oneYear {
                if formatter.locale.identifier == "en_US" {
                    formatter.dateFormat = "MMM dd"
                } else {
                    formatter.dateFormat = "dd MMM"
                }
            } else {
                if formatter.locale.identifier == "en_US" {
                    formatter.dateFormat = "MMM dd, yyyy"
                } else {
                    formatter.dateFormat = "dd MMM yyyy"
                }
            }
            return formatter.string(from: date)
        }
    }
    
    public func dayOfWeek() -> Int {
        //logger.log("dayOfWeek")
        let seconds = Int(self.timeIntervalSinceReferenceDate)
        let days = seconds / 60 / 60 / 24
        return (days + 1) % 7 // Reference date is 1/1/2001 which was Monday, so we need to add one, as the week starts on Sunday
    }
    
    // MARK: - Private functions
    
    static func friendlyDateStringFrom(timeInterval: TimeInterval) -> String {
        let now = Date.timeIntervalSinceReferenceDate
        let diff = now - timeInterval
        if diff < 0 {
            return "0s"
        } else if diff < 60.0 {
            return String(format: "%0.0fs", diff)
        } else if diff < 60.0*60.0 {
            return String(format: "%0.0fm", diff / oneMinute)
        } else if diff < 60.0*60.0*24.0 {
            return String(format: "%0.0fh", diff / oneHour)
        } else if diff < 60.0*60.0*24.0*7.0 {
            return String(format: "%0.0fd", diff / oneDay)
        } else if diff < 60.0*60.0*24.0*30.0*6 {
            let date = Date(timeIntervalSinceReferenceDate: timeInterval)
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd"
            formatter.locale = Locale.current
            return formatter.string(from: date)
        } else {
            let date = Date(timeIntervalSinceReferenceDate: timeInterval)
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd, yy"
            formatter.locale = Locale.current
            return formatter.string(from: date)
        }
    }
    
}
