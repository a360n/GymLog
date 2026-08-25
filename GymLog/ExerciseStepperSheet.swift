//
//  ExerciseStepperSheet.swift
//  GymLog
//

import Foundation
import SwiftUI
import SwiftData
import UserNotifications

struct ExerciseStepperSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var workoutService = WorkoutService()
    
    let exercise: ProgramExercise
    let session: WorkoutSession
    var onFinished: (_ saved: Bool) -> Void

    @State private var entry: WorkoutEntry?
    
    // Interactive inputs by Set Index
    @State private var weightInputs: [Int: String] = [:]
    @State private var repsInputs: [Int: String] = [:]
    @State private var rpeBySet: [Int: Int] = [:]
    @State private var noteBySet: [Int: String] = [:]
    @State private var completedSets: Set<Int> = []
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    
    private var setsCount: Int { max(1, exercise.targetSets) }
    
    // Muscle group theme color
    private var muscleColor: Color {
        MuscleTheme.color(for: exercise.targetMuscle.group)
    }
    
    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    var body: some View {
        ZStack {
            AppBackground()
            
            VStack(alignment: .leading, spacing: 0) {
                // Drag Indicator & Header
                VStack(alignment: .leading, spacing: 10) {
                    Capsule()
                        .frame(width: 42, height: 5)
                        .foregroundStyle(.secondary.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.title3.bold())
                                .foregroundStyle(AppColors.neutral(scheme))
                            
                            HStack(spacing: 8) {
                                Text(exercise.targetMuscle.display)
                                    .font(.caption.bold())
                                    .foregroundStyle(muscleColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(muscleColor.opacity(0.15))
                                    .clipShape(Capsule())
                                
                                Text("\(setsCount) Sets × Target \(exercise.targetReps) Reps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            finishAndDismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                
                Divider().background(.secondary.opacity(0.2))
                
                // Active Multi-Set Logging Cards
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(1...setsCount, id: \.self) { setIndex in
                            setCard(for: setIndex)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, workoutService.timerRunning ? 100 : 80) // Spacing for timer / bottom button
                }
                .scrollIndicators(.hidden)
            }
            .overlay(alignment: .bottom) {
                bottomActionBar
            }
        }
        .interactiveDismissDisabled(workoutService.timerRunning)
        .onAppear {
            // Order is important: compute previous weights first to allow pre-filling
            workoutService.computePreviousBySetAndRPE(
                for: exercise.name,
                programId: session.programId,
                sessionDate: session.date,
                setsCount: setsCount,
                in: ctx
            )
            workoutService.computeSuggestionsPerSet(setsCount: setsCount)
            loadOrCreateEntry()
        }
        .onDisappear {
            workoutService.stopTimer()
            saveAllSetsToDatabase(shouldInsertSession: false)
        }
    }
    
    // MARK: - Set Card Builder
    
    @ViewBuilder
    private func setCard(for setIndex: Int) -> some View {
        let isSetDone = completedSets.contains(setIndex)
        let prevWeight = workoutService.previousBySet[setIndex]
        let prevReps = exercise.repsForSet(setIndex)
        let suggestedWeight = workoutService.suggestedBySet[setIndex]
        
        VStack(alignment: .leading, spacing: 10) {
            // Main Set Stats Row
            HStack(spacing: 10) {
                // Set Badge Circle
                Text("\(setIndex)")
                    .font(.subheadline.bold())
                    .foregroundStyle(isSetDone ? .white : muscleColor)
                    .frame(width: 28, height: 28)
                    .background(isSetDone ? muscleColor : muscleColor.opacity(0.12))
                    .clipShape(Circle())
                
                // Previous stats column
                VStack(alignment: .leading, spacing: 2) {
                    Text("PREV")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    if let pw = prevWeight {
                        Text("\(UnitsSettings.format(pw)) kg × \(prevReps)")
                            .font(.caption.bold())
                            .foregroundStyle(AppColors.neutral(scheme).opacity(0.8))
                    } else if let sw = suggestedWeight {
                        Text("Sug: \(UnitsSettings.format(sw)) kg")
                            .font(.caption)
                            .foregroundStyle(muscleColor.opacity(0.8))
                    } else {
                        Text("—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, alignment: .leading)
                
                Spacer()
                
                // Weight Stepper Input
                HStack(spacing: 4) {
                    Button {
                        adjustWeight(for: setIndex, delta: -2.5)
                    } label: {
                        Image(systemName: "minus")
                            .font(.caption.bold())
                            .frame(width: 24, height: 24)
                            .background(.secondary.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .disabled(isSetDone)
                    
                    TextField("0", text: Binding(
                        get: { weightInputs[setIndex] ?? "" },
                        set: { weightInputs[setIndex] = $0; handleInputChange(for: setIndex) }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.body.bold())
                    .frame(width: 46, height: 28)
                    .background(.secondary.opacity(0.08))
                    .cornerRadius(6)
                    .disabled(isSetDone)
                    .submitLabel(.done)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("تم") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }
                    }
                    
                    Button {
                        adjustWeight(for: setIndex, delta: 2.5)
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .frame(width: 24, height: 24)
                            .background(.secondary.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .disabled(isSetDone)
                }
                
                Spacer()
                
                // Reps Stepper Input
                HStack(spacing: 4) {
                    Button {
                        adjustReps(for: setIndex, delta: -1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.caption.bold())
                            .frame(width: 24, height: 24)
                            .background(.secondary.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .disabled(isSetDone)
                    
                    TextField("0", text: Binding(
                        get: { repsInputs[setIndex] ?? "" },
                        set: { repsInputs[setIndex] = $0; handleInputChange(for: setIndex) }
                    ))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.body.bold())
                    .frame(width: 36, height: 28)
                    .background(.secondary.opacity(0.08))
                    .cornerRadius(6)
                    .disabled(isSetDone)
                    .submitLabel(.done)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("تم") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }
                    }
                    
                    Button {
                        adjustReps(for: setIndex, delta: 1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .frame(width: 24, height: 24)
                            .background(.secondary.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .disabled(isSetDone)
                }
                
                Spacer()
                
                // Completion Checkmark
                Button {
                    toggleSetCompletion(setIndex: setIndex)
                } label: {
                    Image(systemName: isSetDone ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSetDone ? muscleColor : .secondary.opacity(0.7))
                        .scaleEffect(isSetDone ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isSetDone)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
            
            // Sub-row for RPE & Optional Notes (only visible if the set is active or logged)
            HStack(spacing: 12) {
                // RPE pills
                HStack(spacing: 5) {
                    Text("RPE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 2)
                    
                    ForEach(6...10, id: \.self) { rpeVal in
                        let isSelected = rpeBySet[setIndex] == rpeVal
                        Button {
                            rpeBySet[setIndex] = isSelected ? nil : rpeVal
                            handleInputChange(for: setIndex)
                        } label: {
                            Text("\(rpeVal)")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 20, height: 20)
                                .background(isSelected ? muscleColor : .secondary.opacity(0.1))
                                .foregroundStyle(isSelected ? .white : .secondary)
                                .clipShape(Circle())
                        }
                        .disabled(isSetDone)
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Notes Input
                TextField("Add set note...", text: Binding(
                    get: { noteBySet[setIndex] ?? "" },
                    set: { noteBySet[setIndex] = $0; handleInputChange(for: setIndex) }
                ))
                .font(.caption)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.06))
                .cornerRadius(6)
                .disabled(isSetDone)
                .frame(maxWidth: 140)
            }
            .padding(.top, 4)
            .padding(.leading, 38)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(scheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.01))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSetDone ? muscleColor.opacity(0.4) : .secondary.opacity(0.12), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isSetDone)
    }
    
    // MARK: - Floating Timer and Bottom Action Bar
    
    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            // Floating Rest Timer Card
            if workoutService.timerRunning {
                HStack(spacing: 12) {
                    // Circular Countdown ring
                    ZStack {
                        Circle()
                            .stroke(.secondary.opacity(0.2), lineWidth: 3)
                        Circle()
                            .trim(from: 0.0, to: CGFloat(workoutService.timerRemaining) / 120.0)
                            .stroke(muscleColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: workoutService.timerRemaining)
                        
                        Image(systemName: "timer")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(muscleColor)
                    }
                    .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rest Timer")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Text(formatTimer(workoutService.timerRemaining))
                            .monospacedDigit()
                            .font(.subheadline.bold())
                            .foregroundStyle(muscleColor)
                    }
                    
                    Spacer()
                    
                    Button {
                        workoutService.timerRemaining = min(workoutService.timerRemaining + 30, 300)
                    } label: {
                        Text("+30s")
                            .font(.caption.bold())
                            .foregroundStyle(muscleColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(muscleColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        workoutService.stopTimer()
                    } label: {
                        Text("Skip")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(18)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(muscleColor.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Finish Exercise Button
            let allCompleted = completedSets.count == setsCount
            Button {
                saveAllSetsToDatabase(shouldInsertSession: true)
                if let entry = entry {
                    let max1RM = entry.sets.map { set in
                        let w = set.weight
                        let r = Double(set.reps)
                        return w * (1.0 + r / 30.0) // Epley formula
                    }.max() ?? 0
                    entry.estimatedOneRM = max1RM
                }
                if let entry = entry {
                    workoutService.finalizeExerciseAndPR(
                        entry: entry,
                        programId: session.programId,
                        sessionDate: session.date,
                        in: ctx
                    )
                }
                finishAndDismiss()
            } label: {
                HStack {
                    Spacer()
                    Label("Finish Exercise", systemImage: "checkmark.seal.fill")
                        .font(.body.bold())
                        .foregroundStyle(allCompleted ? .white : .secondary)
                    Spacer()
                }
                .padding(.vertical, 15)
                .background(
                    allCompleted ?
                    AnyView(LinearGradient(colors: [muscleColor, muscleColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                    AnyView(Color.secondary.opacity(0.15))
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: allCompleted ? muscleColor.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color.clear, AppColors.background(scheme).opacity(0.95), AppColors.background(scheme)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Logic & Database Persistance
    
    private func loadOrCreateEntry() {
        if let ex = session.entries.first(where: { $0.exerciseName == exercise.name }) {
            entry = ex
        } else {
            let e = WorkoutEntry(exerciseName: exercise.name, session: session)
            e.programExerciseId = exercise.id
            e.targetMuscleAtLogRaw = exercise.targetMuscleRaw
            e.exerciseDisplayNameAtLog = exercise.name
            e.targetSetsAtLog = exercise.targetSets
            e.targetRepsAtLog = exercise.targetReps
            var setsArr: [WorkoutSet] = []
            for i in 1...setsCount {
                setsArr.append(WorkoutSet(setIndex: i, reps: exercise.repsForSet(i), weight: 0))
            }
            e.sets = setsArr
            session.entries.append(e)
            entry = e
            if session.modelContext != nil {
                ctx.saveOrLog()
            }
        }

        guard let en = entry else { return }
        
        // Ensure array completion (in case setsCount changed)
        var map = Dictionary(uniqueKeysWithValues: en.sets.map { ($0.setIndex, $0) })
        for i in 1...setsCount where map[i] == nil {
            let s = WorkoutSet(setIndex: i, reps: exercise.repsForSet(i), weight: 0)
            en.sets.append(s); map[i] = s
        }
        for i in 1...setsCount { map[i]?.reps = exercise.repsForSet(i) }

        // Populate fields based on existing data
        for s in en.sets {
            if s.weight > 0 {
                weightInputs[s.setIndex] = UnitsSettings.format(s.weight)
                completedSets.insert(s.setIndex)
            } else {
                // Pre-fill fields with historical or suggestions for frictionless logging
                let prefilledWeight = workoutService.previousBySet[s.setIndex] ?? workoutService.suggestedBySet[s.setIndex] ?? 0.0
                weightInputs[s.setIndex] = prefilledWeight > 0 ? UnitsSettings.format(prefilledWeight) : ""
            }
            
            repsInputs[s.setIndex] = String(s.reps)
            
            if let r = s.rpe { rpeBySet[s.setIndex] = r }
            if let n = s.note, !n.isEmpty { noteBySet[s.setIndex] = n }
        }
        
        if session.modelContext != nil {
            ctx.saveOrLog()
        }
    }
    
    private func toggleSetCompletion(setIndex: Int) {
        if completedSets.contains(setIndex) {
            completedSets.remove(setIndex)
            workoutService.stopTimer()
        } else {
            // Save state immediately
            completedSets.insert(setIndex)
            saveAllSetsToDatabase(shouldInsertSession: true)
            
            // Fire up rest timer (if not the last set)
            if setIndex < setsCount {
                workoutService.startTimer {}
                scheduleRestNotification(seconds: workoutService.timerRemaining)
            }
        }
    }
    
    private func handleInputChange(for setIndex: Int) {
        // If they alter input, they might want to uncheck
        // but we don't force it unless they uncompleted manually.
        saveAllSetsToDatabase(shouldInsertSession: false)
    }

    private func saveAllSetsToDatabase(shouldInsertSession: Bool) {
        guard let en = entry else { return }
        
        for i in 1...setsCount {
            let displayVal = Double(cleanNumberString(weightInputs[i] ?? "")) ?? 0.0
            let weightVal: Double = unit == .kg ? displayVal : UnitsSettings.convertToKg(fromCurrent: displayVal)
            let repsVal = Int(repsInputs[i] ?? "") ?? exercise.repsForSet(i)
            let rpeVal = rpeBySet[i]
            let noteVal = noteBySet[i]
            
            if let dbSet = en.sets.first(where: { $0.setIndex == i }) {
                dbSet.weight = weightVal
                dbSet.reps = repsVal
                dbSet.rpe = rpeVal
                dbSet.note = noteVal
            }
        }
        
        en.sets.sort { $0.setIndex < $1.setIndex }
        
        // Insert parent session dynamically if required (frictionless database pollution prevention)
        if shouldInsertSession && session.modelContext == nil {
            ctx.insert(session)
        }
        
        if session.modelContext != nil {
            ctx.saveOrLog()
        }
    }
    
    // MARK: - Adjustment Helpers
    
    private func adjustWeight(for setIndex: Int, delta: Double) {
        let currentDisplay = Double(cleanNumberString(weightInputs[setIndex] ?? "")) ?? 0.0
        let step = unit.step
        let newDisplay = max(0, currentDisplay + delta)
        // Convert display back to kg for storage
        let newKg = unit == .kg ? newDisplay : UnitsSettings.convertToKg(fromCurrent: newDisplay)
        weightInputs[setIndex] = UnitsSettings.format(newKg)
        handleInputChange(for: setIndex)
    }
    
    private func adjustReps(for setIndex: Int, delta: Int) {
        let current = Int(repsInputs[setIndex] ?? "") ?? exercise.repsForSet(setIndex)
        let newReps = max(0, current + delta)
        repsInputs[setIndex] = String(newReps)
        handleInputChange(for: setIndex)
    }
    
    private func cleanNumberString(_ val: String) -> String {
        val.replacingOccurrences(of: ",", with: ".")
    }
    
    private func numberString(_ d: Double) -> String {
        d == floor(d) ? String(format: "%.0f", d) : String(format: "%.1f", d)
    }
    
    private func formatTimer(_ s: Int) -> String {
        let m = s / 60, r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
    
    private func finishAndDismiss() {
        onFinished(true)
        dismiss()
    }
    
    private func scheduleRestNotification(seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let content = UNMutableNotificationContent()
        content.title = "انتهى وقت الراحة"
        content.body = "العودة للتمرين الآن"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let req = UNNotificationRequest(identifier: "rest_timer_\(UUID().uuidString)", content: content, trigger: trigger)
        center.add(req, withCompletionHandler: nil)
    }
}

// MARK: - Premium Muscle Color Theme Helper

struct MuscleTheme {
    static func color(for group: String) -> Color {
        switch group {
        case "Chest":
            return Color(hex: "#FF453A") // Dynamic Apple Red / Crimson
        case "Arms", "Biceps", "Triceps", "Forearms":
            return Color(hex: "#5E5CE6") // Deep Premium Violet / Indigo
        case "Back":
            return Color(hex: "#30D158") // Emerald Green
        case "Shoulders":
            return Color(hex: "#FF9F0A") // Amber Gold / Yellow
        case "Thighs", "Legs", "Calves", "Glutes":
            return Color(hex: "#0A84FF") // Cerulean Blue
        default:
            return Color(hex: "#BF5AF2") // Amethyst purple
        }
    }
}
