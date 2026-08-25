//
//  WorkoutService.swift
//  GymLog
//

import Foundation
import SwiftData
import AVFoundation

@MainActor
final class WorkoutService: ObservableObject {
    @Published var previousBySet: [Int: Double] = [:]
    @Published var previousRPEBySet: [Int: Int] = [:]
    @Published var suggestedBySet: [Int: Double] = [:]

    @Published var timerRunning = false
    @Published var timerRemaining = 120
    private var timer: Timer?

    // Calculates previous session data for the same exercise
    func computePreviousBySetAndRPE(for exerciseName: String, programId: UUID, sessionDate: Date, setsCount: Int, in ctx: ModelContext) {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { session in
                session.programId == programId && session.isCompleted && session.date < sessionDate
            }
        )
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        let history = (try? ctx.fetch(descriptor)) ?? []

        var bestWeight: [Int: Double] = [:]
        var bestRPE: [Int: Int] = [:]

        for s in history {
            for e in s.entries where e.exerciseName == exerciseName {
                for st in e.sets.sorted(by: { $0.setIndex < $1.setIndex }) {
                    if bestWeight[st.setIndex] == nil, st.weight > 0 {
                        bestWeight[st.setIndex] = st.weight
                    }
                    if bestRPE[st.setIndex] == nil, let r = st.rpe {
                        bestRPE[st.setIndex] = r
                    }
                }
            }
            if bestWeight.count >= setsCount { break }
        }

        self.previousBySet = bestWeight
        self.previousRPEBySet = bestRPE
    }

    // Suggestions based on RPE and weight
    func computeSuggestionsPerSet(setsCount: Int) {
        var map: [Int: Double] = [:]
        for i in 1...setsCount {
            let w = previousBySet[i]
            let r = previousRPEBySet[i]
            if let s = suggestNext(weight: w, rpe: r) {
                map[i] = s
            }
        }
        self.suggestedBySet = map
    }

    private func suggestNext(weight: Double?, rpe: Int?) -> Double? {
        guard let w = weight, w > 0 else { return nil }
        let r = rpe ?? 8  // If no previous RPE, assume 8 (medium)

        let raw: Double
        if r <= 6 {
            raw = w + 2.5           // Easy -> Increase
        } else if r >= 9 {
            raw = max(0, w - 2.5)   // Hard -> Decrease
        } else {
            raw = w                 // Medium -> Keep
        }
        return roundToIncrement(raw, increment: 2.5)
    }

    private func roundToIncrement(_ value: Double, increment: Double = 2.5) -> Double {
        guard increment > 0 else { return value }
        let steps = (value / increment).rounded()
        return max(0, steps * increment)
    }

    // Timer management
    func startTimer(onComplete: @escaping () -> Void) {
        timer?.invalidate()
        timerRemaining = 120
        timerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { return }
            Task { @MainActor in
                if self.timerRemaining > 0 {
                    self.timerRemaining -= 1
                } else {
                    t.invalidate()
                    self.timerRunning = false
                    // Haptic feedback
                    AudioServicesPlaySystemSound(1009) // Taptic pop/success equivalent
                    onComplete()
                }
            }
        }
    }

    func resetTimerAndStart(onComplete: @escaping () -> Void) {
        timer?.invalidate()
        timerRemaining = 120
        startTimer(onComplete: onComplete)
    }

    func stopTimer() {
        timer?.invalidate()
        timerRunning = false
    }

    deinit {
        timer?.invalidate()
    }

    // Finalize exercise and determine PRs
    func finalizeExerciseAndPR(entry: WorkoutEntry, programId: UUID, sessionDate: Date, in ctx: ModelContext) {
        try? ctx.save()

        let sets = entry.sets
        let currentMax = sets.map(\.weight).max() ?? 0
        let currentVolume = sets.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
        let current1RM = sets.map { $0.weight * (1.0 + Double($0.reps)/30.0) }.max() ?? 0

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { session in
                session.programId == programId && session.isCompleted && session.date < sessionDate
            }
        )
        let history = (try? ctx.fetch(descriptor)) ?? []
        var bestMax = 0.0, bestVol = 0.0, best1rm = 0.0
        for s in history {
            for e in s.entries where e.exerciseName == entry.exerciseName {
                let hs = e.sets
                bestMax = max(bestMax, hs.map(\.weight).max() ?? 0)
                bestVol = max(bestVol, hs.reduce(0.0) { $0 + Double($1.reps) * $1.weight })
                let h1 = hs.map { $0.weight * (1.0 + Double($0.reps)/30.0) }.max() ?? 0
                best1rm = max(best1rm, h1)
            }
        }

        entry.prMaxWeight = currentMax > bestMax && currentMax > 0
        entry.prVolume = currentVolume > bestVol && currentVolume > 0
        entry.prOneRM = current1RM > best1rm && current1RM > 0
        try? ctx.save()
    }
}
