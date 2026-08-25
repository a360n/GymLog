//
//  DayDetailView.swift
//  GymLog
//

import Foundation
import SwiftUI
import SwiftData

struct DayDetailView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State var program: Program
    @State var day: ProgramDay

    // Rename Day
    @State private var showRenameDaySheet = false
    @State private var tempDayTitle = ""

    // Delete day confirm
    @State private var showDeleteDayConfirm = false

    // Add Exercise Sheet
    @State private var showAddExerciseSheet = false
    @State private var newExName = ""
    @State private var newSets = 3
    @State private var newReps = 10

    var body: some View {
        ZStack { AppBackground() }
            .overlay(
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(day.title)
                            .font(.title2.bold())
                            .foregroundStyle(AppColors.neutral(scheme))
                        Spacer()
                        Menu {
                            Button("Rename Day") {
                                tempDayTitle = day.title
                                showRenameDaySheet = true
                            }
                            Button("Delete Day", role: .destructive) {
                                showDeleteDayConfirm = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }

                    // Exercises list
                    List {
                        ForEach(day.exercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { ex in
                            NavigationLink(destination: ExerciseDetailView(day: day, exercise: ex)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ex.name)
                                            .foregroundStyle(AppColors.neutral(scheme))
                                        Text("\(ex.targetSets) sets × \(ex.targetReps) reps")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(AppColors.primary(scheme).opacity(0.4))
                        }
                    }
                    .scrollContentBackground(.hidden)

                    Button {
                        newExName = ""
                        newSets = 3
                        newReps = 10
                        showAddExerciseSheet = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.secondary(scheme))
                }
                .padding()
            )
            .sheet(isPresented: $showRenameDaySheet) {
                RenameDaySheet(value: $tempDayTitle) {
                    let t = tempDayTitle.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty {
                        day.title = t
                        try? ctx.save()
                    }
                }
                .presentationDetents([.fraction(0.3)])
            }
            .sheet(isPresented: $showAddExerciseSheet) {
                AddExerciseSheet(name: $newExName, sets: $newSets, reps: $newReps) { perSet, target in
                    let next = (day.exercises.map { $0.orderIndex }.max() ?? -1) + 1
                    let e = ProgramExercise(
                        name: newExName.isEmpty ? "Exercise \(next + 1)" : newExName,
                        targetSets: newSets,
                        targetReps: newReps,
                        orderIndex: next,
                        perSetReps: perSet,
                        targetMuscle: target
                    )
                    day.exercises.append(e)
                    try? ctx.save()
                }
                .presentationDetents([.fraction(0.45)])
            }
            .confirmationDialog(
                "Delete day?",
                isPresented: $showDeleteDayConfirm
            ) {
                Button("Delete", role: .destructive) {
                    if let idx = program.days.firstIndex(where: { $0.id == day.id }) {
                        program.days.remove(at: idx)
                        try? ctx.save()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the day and its exercises.")
            }
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RenameDaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Binding var value: String
    var onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rename Day")
                .font(.headline)
                .foregroundStyle(AppColors.neutral(scheme))
            TextField("Day title", text: $value)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Save") { onSave(); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.secondary(scheme))
            }
        }
        .padding()
        .background(AppColors.primary(scheme).opacity(0.25))
    }
}

// AddExerciseSheet
private struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Binding var name: String
    @Binding var sets: Int
    @Binding var reps: Int
    var onAdd: (_ perSetReps: [Int], _ target: TargetMuscle) -> Void

    @State private var customReps: [Int] = []
    @State private var selectedMuscle: TargetMuscle = .chestMid

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Exercise")
                .font(.headline)
                .foregroundStyle(AppColors.neutral(scheme))

            TextField("Exercise name", text: $name)
                .textFieldStyle(.roundedBorder)

            Picker("Target muscle", selection: $selectedMuscle) {
                ForEach(groupedMuscles.keys.sorted(), id: \.self) { group in
                    Section(group) {
                        ForEach(groupedMuscles[group] ?? []) { m in
                            Text(m.display).tag(m)
                        }
                    }
                }
            }
            .pickerStyle(.menu)

            Stepper("Sets: \(sets)", value: $sets, in: 1...20)
                .onChange(of: sets) { _, newValue in
                    syncCustomArray(to: newValue)
                }

            ForEach(customReps.indices, id: \.self) { i in
                HStack {
                    Text("Set \(i+1)")
                    Spacer()
                    Stepper("Reps: \(customReps[i])", value: Binding(
                        get: { customReps[i] },
                        set: { customReps[i] = max(1, $0) }
                    ), in: 1...60)
                    Button(role: .destructive) {
                        customReps.remove(at: i)
                        sets = max(1, sets - 1)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }

            HStack {
                Spacer()
                Button("Add") {
                    onAdd(customReps, selectedMuscle)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.secondary(scheme))
            }
        }
        .padding()
        .background(AppColors.primary(scheme).opacity(0.25))
        .onAppear { syncCustomArray(to: sets, fillWith: reps) }
    }

    private func syncCustomArray(to newSets: Int, fillWith: Int? = nil) {
        if customReps.count < newSets {
            let fill = max(1, fillWith ?? reps)
            customReps.append(contentsOf: Array(repeating: fill, count: newSets - customReps.count))
        } else if customReps.count > newSets {
            customReps = Array(customReps.prefix(newSets))
        }
    }

    private var groupedMuscles: [String: [TargetMuscle]] {
        Dictionary(grouping: TargetMuscle.allCases, by: { $0.group })
    }
}
