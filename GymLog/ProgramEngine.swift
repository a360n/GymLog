//
//  ProgramEngine.swift
//  GymLog
//
//  Created by Ali Al-Khazali on 9/9/25.
//

import Foundation
import SwiftData

enum ProgramEngine {
    /// Counts completed sessions for the given program ID.
    static func completedCount(for program: Program, ctx: ModelContext) -> Int {
        let all = (try? ctx.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        return all.filter { $0.programId == program.id && $0.isCompleted }.count
    }

    static func currentDayIndex(for program: Program, completedCount: Int) -> Int {
        let daysCount = program.days.count
        guard daysCount > 0 else { return 0 }
        return completedCount % daysCount
    }

    static func currentProgramDay(for program: Program, ctx: ModelContext) -> ProgramDay? {
        let c = completedCount(for: program, ctx: ctx)
        let idx = currentDayIndex(for: program, completedCount: c)
        let sorted = program.days.sorted { $0.orderIndex < $1.orderIndex }
        return sorted.indices.contains(idx) ? sorted[idx] : nil
    }
}
