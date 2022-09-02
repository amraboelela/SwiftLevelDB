//
//  Task.swift
//  SwiftLevelDB
//
//  Created by Amr Aboelela on 9/2/22.
//  Copyright © 2022 Amr Aboelela.
//

import Foundation

@available(iOS 13.0, *)
@available(macOS 10.15.0, *)
extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}
