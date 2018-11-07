//
//  Date.swift
//  DelyveryFoundation
//
//  Created by Amr Aboelela on 6/5/18.
//  Copyright © 2018 Delyvery Inc. All rights reserved.
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
    
    static var millisecondsSinceReferenceDate: Int {
        return Int(Date.timeIntervalSinceReferenceDate * 1000)
    }
    
    public static var now: Int {
        return Int(Date().timeIntervalSince1970)
    }
    
    public var isToday: Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let now = Date().timeIntervalSinceReferenceDate
        let timeDiff = now - self.timeIntervalSinceReferenceDate
        formatter.dateFormat = "MMM dd"
        if timeDiff < Date.oneDay && formatter.string(from: self) == formatter.string(from: Date()) {
            return true
        }
        return false
    }
    
    public var sectionDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let now = Date().timeIntervalSinceReferenceDate
        let selfTime = self.timeIntervalSinceReferenceDate
        let timeDiff = now - selfTime
        if timeDiff < Date.oneYear {
            if self.isToday {
                return "Today"
            } else {
                if formatter.locale.identifier == "en_US" {
                    formatter.dateFormat = "MMM dd"
                } else {
                    formatter.dateFormat = "dd MMM"
                }
            }
        } else {
            if formatter.locale.identifier == "en_US" {
                formatter.dateFormat = "MMM dd, yyyy"
            } else {
                formatter.dateFormat = "dd MMM yyyy"
            }
        }
        return formatter.string(from: self)
    }
    
    public var time: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
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
    
    public static func minutes(fromSeconds seconds: Int) -> Int {
        var result = 0
        result = Int(ceil(Double(seconds) / 60.0))
        return result
    }
    
    // MARK: - Private functions
    
    func dayOfWeek() -> Int {
        return Calendar.current.dateComponents([.weekday], from: self).weekday ?? 0
    }
    
    static func friendlyDateStringFrom(timeInterval: TimeInterval) -> String {
        let now = Date.timeIntervalSinceReferenceDate
        let diff = now - timeInterval
        if diff < 0 {
            return "0s"
        } else if diff < 60.0 {
            return String(format: "%0.0fs", diff)
        } else if diff < 60.0*60.0 {
            return String(format: "%0.0fm", diff / 60.0)
        } else if diff < 60.0*60.0*24.0 {
            return String(format: "%0.0fh", diff / 60.0 / 60.0)
        } else if diff < 60.0*60.0*24.0*7.0 {
            return String(format: "%0.0fd", diff / 60.0 / 60.0 / 24.0)
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
