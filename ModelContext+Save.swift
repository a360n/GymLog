// ModelContext+Save.swift
// GymLog

import SwiftData

extension ModelContext {
    /// Saves the context and logs any error instead of failing silently.
    func saveOrLog(file: StaticString = #fileID, line: UInt = #line) {
        do {
            try save()
        } catch {
            print("SwiftData save failed at \(file):\(line): \(error)")
        }
    }
}
