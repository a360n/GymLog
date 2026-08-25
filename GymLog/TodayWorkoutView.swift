//
//  TodayWorkoutView.swift
//  GymLog
//
//  Created by Ali Al-Khazali on 9/9/25.
//

import Foundation
import SwiftUI
import SwiftData

struct TodayWorkoutView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    
    let program: Program
    
    @State private var day: ProgramDay?
    @State private var session: WorkoutSession?
    @State private var sheetExercise: ProgramExercise?
    @State private var completedExerciseIds: Set<UUID> = []
    
    var body: some View {
        ZStack { AppBackground() }
            .overlay(
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today's Workout")
                        .font(.title.bold())
                        .foregroundStyle(AppColors.neutral(scheme))
                    if let s = session {
                        Text(dateLabel(for: s))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        Button {
                            goToPreviousDay()
                        } label: {
                            Label("Previous", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            skipCurrentDayAndAdvance()
                        } label: {
                            Label("Skip Day", systemImage: "forward.end.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.accent(scheme))
                    }
                    if let day {
                        Text(day.title)
                            .font(.headline)
                            .foregroundStyle(AppColors.secondary(scheme))
                        
                        List {
                            ForEach(sortedExercises(day)) { ex in
                                Button {
                                    // Ensure session is ready before opening the sheet in the next cycle
                                    if session == nil { setupDayAndSession() }
                                    DispatchQueue.main.async { sheetExercise = ex }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(ex.name)
                                                .foregroundStyle(AppColors.neutral(scheme))
                                            Text("\(ex.targetSets) Sets • avg \(ex.targetReps) Reps")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if completedExerciseIds.contains(ex.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(AppColors.secondary(scheme))
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .listRowBackground(AppColors.primary(scheme).opacity(0.45))
                                .disabled(completedExerciseIds.contains(ex.id))
                            }
                        }
                        .scrollContentBackground(.hidden)
                        
                        if allExercisesCompleted {
                            Button { finishSession() } label: {
                                Label("Finish Session", systemImage: "checkmark.seal.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppColors.accent(scheme))
                        }
                    } else {
                        Text("No workout scheduled for today.")
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer(minLength: 0)
                }
                    .padding()
            )
            .onAppear { setupDayAndSession() }
            .sheet(item: $sheetExercise) { ex in
                if let s = session {
                    ExerciseStepperSheet(
                        exercise: ex,
                        session: s,
                        onFinished: { _ in
                            markExerciseCompletedIfReady(ex)
                        }
                    )
                    .id(ex.id) // يجبر إعادة بناء محتوى الشيت لأول تمرين
                    .presentationDetents([.fraction(0.5), .large])
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Preparing session…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .presentationDetents([.fraction(0.3)])
                }
            }
    }
    // All days sorted by orderIndex
    private var sortedDaysInProgram: [ProgramDay] {
        program.days.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    // Fetch the current day's session or create a new one (without marking it as completed)
    @discardableResult
    private func ensureSessionForCurrentDay() -> WorkoutSession? {
        guard let d = day else { return nil }
        // Search for an incomplete session for this day using Predicate
        let programId = program.id
        let dayOrderIndex = d.orderIndex
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { session in
                session.programId == programId && session.dayOrderIndex == dayOrderIndex && !session.isCompleted
            }
        )
        let all = (try? ctx.fetch(descriptor)) ?? []
        if let exist = all.first {
            self.session = exist
            return exist
        }
        // Create a new session in-memory only (transient)
        let s = WorkoutSession(
            date: Date(),
            programId: program.id,
            dayOrderIndex: d.orderIndex,
            titleSnapshot: d.title,
            isCompleted: false
        )
        self.session = s
        return s
    }
    
    // Copies exercises from the last completed session for this day (if any) and injects into the current session
    private func autofillCurrentDayFromLastSameDay() {
        guard let d = day,
              let s = ensureSessionForCurrentDay() else { return }
        
        let programId = program.id
        let dayOrderIndex = d.orderIndex
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { session in
                session.programId == programId && session.dayOrderIndex == dayOrderIndex && session.isCompleted
            }
        )
        var all = (try? ctx.fetch(descriptor)) ?? []
        all.sort { $0.date > $1.date }
        let prev = all.first
        
        // Clear old entries (if any) before autofill
        s.entries.removeAll()
        
        for ex in d.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let entry = WorkoutEntry(exerciseName: ex.name, session: s)
            if let pe = prev?.entries.first(where: { $0.exerciseName == ex.name }) {
                // Copy sets exactly as they are (weight/reps/rpe/note)
                entry.sets = pe.sets.map {
                    WorkoutSet(setIndex: $0.setIndex,
                               reps: $0.reps,
                               weight: $0.weight,
                               rpe: $0.rpe,
                               note: $0.note)
                }
            } else {
                // If no previous history, build default sets (0 weight)
                entry.sets = (1...max(1, ex.targetSets)).map {
                    WorkoutSet(setIndex: $0,
                               reps: ex.targetReps,
                               weight: 0,
                               rpe: nil,
                               note: nil)
                }
            }
            s.entries.append(entry)
        }
        
        if s.modelContext != nil {
            ctx.saveOrLog()
        }
    }
    
    // Completes the current day session (after autofill) and advances to the next day
    // Marks the day as skipped + completed with the current date before advancing
    private func skipCurrentDayAndAdvance() {
        guard let d = day else { return }
        // Create / Fetch today's session
        guard let s = ensureSessionForCurrentDay() else { return }

        // Optional autofill logic based on weights from the last similar day
        // autofillCurrentDayFromLastSameDay()

        // Mark the session as skipped and completed with current date
        s.isSkipped = true
        s.isCompleted = true
        s.date = Date()
        
        if s.modelContext == nil {
            ctx.insert(s)
        }
        ctx.saveOrLog()

        // Optional: Update UI completion status before moving
        let ids = d.exercises.map(\.id)
        completedExerciseIds = Set(ids)

        // Move to the next day
        moveToNextDay(from: d)
    }
    private func dateLabel(for s: WorkoutSession) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        let when = df.string(from: s.date)
        return s.isSkipped ? "Skipped on \(when)" : "Completed on \(when)"
    }
    // Move to next day (with optional wrap around)
    private func moveToNextDay(from d: ProgramDay) {
        let days = program.days.sorted { $0.orderIndex < $1.orderIndex }
        guard !days.isEmpty else { return }
        if let idx = days.firstIndex(where: { $0.id == d.id }) {
            let next = days[(idx + 1) % days.count]
            self.day = next
            if let s = ensureSessionForCurrentDay(), let d2 = self.day {
                recomputeCompletedFlags(for: s, day: d2)
            }
        }
    }
    private func moveToPreviousDay(from d: ProgramDay) {
        let days = program.days.sorted { $0.orderIndex < $1.orderIndex }
        guard !days.isEmpty else { return }
        if let idx = days.firstIndex(where: { $0.id == d.id }) {
            let prev = days[(idx - 1 + days.count) % days.count]
            self.day = prev
            if let s = ensureSessionForCurrentDay(), let d2 = self.day {
                recomputeCompletedFlags(for: s, day: d2)
            }
        }
    }
    // Go back to the previous day (shows the previous day without altering active sessions)
    private func goToPreviousDay() {
        guard let d = day else { return }
        moveToPreviousDay(from: d)
    }
    // MARK: - Helpers
    
    private func sortedExercises(_ day: ProgramDay) -> [ProgramExercise] {
        day.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    private var allExercisesCompleted: Bool {
        guard let d = day else { return false }
        return completedExerciseIds.count == d.exercises.count && d.exercises.count > 0
    }
    
    private func setupDayAndSession() {
        self.day = ProgramEngine.currentProgramDay(for: program, ctx: ctx)
        guard let d = day else {
            SharedUtils.saveTodaySummary(title: "No workout", exercises: 0)
            return
        }
        
        let programId = program.id
        let dayOrderIndex = d.orderIndex
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { session in
                session.programId == programId && session.dayOrderIndex == dayOrderIndex && !session.isCompleted
            }
        )
        let allSessions = (try? ctx.fetch(descriptor)) ?? []
        if let exist = allSessions.first {
            self.session = exist
            
            // Consider the exercise complete only if all required sets have a weight > 0
            let finishedNames: Set<String> = Set(
                exist.entries.filter { e in
                    guard let ex = d.exercises.first(where: { $0.name == e.exerciseName }) else { return false }
                    let needed = max(1, ex.targetSets)
                    let nonZero = e.sets.filter { $0.weight > 0 }.count
                    return nonZero >= needed
                }.map { $0.exerciseName }
            )
            let doneIds = d.exercises.filter { finishedNames.contains($0.name) }.map { $0.id }
            self.completedExerciseIds = Set(doneIds)
            
        } else {
            let s = WorkoutSession(
                date: Date(),
                programId: program.id,
                dayOrderIndex: d.orderIndex,
                titleSnapshot: d.title,
                isCompleted: false
            )
            self.session = s
            self.completedExerciseIds = []
        }
        SharedUtils.saveTodaySummary(title: d.title, exercises: d.exercises.count)
    }
    
    private func finishSession() {
        guard let s = session, let d = day else { return }
        s.isCompleted = true
        s.isSkipped = false
        s.date = Date()
        
        if s.modelContext == nil {
            ctx.insert(s)
        }
        ctx.saveOrLog()

        // Advance to the next day in the program order, initializing the next session automatically
        moveToNextDay(from: d)
    }
    private func recomputeCompletedFlags(for s: WorkoutSession, day d: ProgramDay) {
        let finishedNames: Set<String> = Set(
            s.entries.filter { e in
                guard let ex = d.exercises.first(where: { $0.name == e.exerciseName }) else { return false }
                let needed = max(1, ex.targetSets)
                let nonZero = e.sets.filter { $0.weight > 0 }.count
                return nonZero >= needed
            }.map { $0.exerciseName }
        )
        let doneIds = d.exercises.filter { finishedNames.contains($0.name) }.map { $0.id }
        self.completedExerciseIds = Set(doneIds)
    }
    private func markExerciseCompletedIfReady(_ ex: ProgramExercise) {
        guard let s = session,
              let entry = s.entries.first(where: { $0.exerciseName == ex.name }) else { return }
        let needed = max(1, ex.targetSets)
        let filled = entry.sets.filter { $0.weight > 0 }.count
        if filled >= needed {
            completedExerciseIds.insert(ex.id)
        }
    }
}

