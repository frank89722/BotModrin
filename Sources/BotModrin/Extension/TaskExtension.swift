//
//  File.swift
//  
//
//  Created by Frank V on 2022/6/29.
//

import Foundation

extension Task where Success == Never, Failure == Never {
    
    public static func sleep(microseconds duration: UInt64) async throws {
        try await sleep(nanoseconds: duration * 1000)
    }
    
    public static func sleep(milliseconds duration: UInt64) async throws {
        try await sleep(microseconds: duration * 1000)
    }
    
    public static func sleep(seconds duration: UInt64) async throws {
        try await sleep(milliseconds: duration * 1000)
    }
}
