//
//  Utilities.swift
//  GymLog
//
//  Created by Ali Al-Khazali on 9/10/25.
//

import Foundation
import SwiftData

// تقريب للخطوة الأقرب (مثلاً 2.5 كغم)
func roundToIncrement(_ value: Double, increment: Double = 2.5) -> Double {
    guard increment > 0 else { return value }
    let steps = (value / increment).rounded()
    return max(0, steps * increment)
}

// اجلب آخر إدخال مكتمل للتمرين قبل تاريخ معيّن
func lastCompletedEntry(
    for exerciseName: String,
    in programId: UUID,
    before date: Date,
    ctx: ModelContext
) -> WorkoutEntry? {
    let sessions = (try? ctx.fetch(FetchDescriptor<WorkoutSession>())) ?? []
    // جلسات قديمة مكتملة لنفس البرنامج
    let history = sessions
        .filter { $0.programId == programId && $0.isCompleted && $0.date < date }
        .sorted { $0.date > $1.date }   // أحدث أولًا

    for s in history {
        if let e = s.entries.first(where: { $0.exerciseName == exerciseName }) {
            // نعتبره مكتملًا إن لكل set وزن > 0
            let needed = max(1, e.sets.count)
            let nonZero = e.sets.filter { $0.weight > 0 }.count
            if nonZero >= needed { return e }
        }
    }
    return nil
}

// احسب اقتراح الوزن القادم اعتمادًا على متوسط RPE ونجاح الستّات ومتوسط الأوزان
func suggestedNextWeight(
    from entry: WorkoutEntry?
) -> Double? {
    guard let entry = entry else { return nil }
    let sets = entry.sets
    guard !sets.isEmpty else { return nil }

    // نجاح: كل الأوزان > 0
    let success = sets.allSatisfy { $0.weight > 0 }

    // متوسط الوزن (للقيم > 0)
    let nonZeroWeights = sets.map(\.weight).filter { $0 > 0 }
    guard !nonZeroWeights.isEmpty else { return nil }
    let avgWeight = nonZeroWeights.reduce(0, +) / Double(nonZeroWeights.count)

    // متوسط RPE (إن لم تُسجّل، نفترض 8)
    let rpes = sets.compactMap(\.rpe)
    let avgRPE: Double = rpes.isEmpty ? 8.0 : (Double(rpes.reduce(0, +)) / Double(rpes.count))

    // منطق الاقتراح:
    // - إن لم ينجح كل الستّات → خفّض
    // - إن avgRPE <= 6 → زد
    // - إن avgRPE >= 9 → خفّض
    // - غير ذلك → ثبّت
    let rawSuggestion: Double
    if !success {
        rawSuggestion = max(0, avgWeight - 2.5)
    } else if avgRPE <= 6 {
        rawSuggestion = avgWeight + 2.5
    } else if avgRPE >= 9 {
        rawSuggestion = max(0, avgWeight - 2.5)
    } else {
        rawSuggestion = avgWeight
    }

    return roundToIncrement(rawSuggestion, increment: 2.5)
}
