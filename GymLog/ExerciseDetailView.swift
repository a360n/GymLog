//
//  ExerciseDetailView.swift
//  GymLog
//

import Foundation
import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State var day: ProgramDay
    @State var exercise: ProgramExercise

    @State private var name: String = ""
    @State private var sets: Int = 3
    @State private var customReps: [Int] = []
    @State private var defaultRepsForNewSets: Int = 10
    @State private var selectedMuscle: TargetMuscle = .chestMid

    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack { AppBackground() }
            .overlay(
                Form {
                    Section("Exercise") {
                        TextField("Name", text: $name)
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
                    }

                    Section("Sets & Reps") {
                        Stepper("Sets: \(sets)", value: $sets, in: 1...30)
                            .onChange(of: sets) { _, newVal in
                                syncCustomArray(to: newVal)
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
                    }

                    Section {
                        Button("Save Changes") {
                            let trimmed = name.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty { exercise.name = trimmed }
                            exercise.targetSets = max(1, sets)
                            exercise.targetReps = customReps.last ?? max(1, exercise.targetReps)
                            exercise.perSetReps = customReps
                            exercise.targetMuscle = selectedMuscle

                            try? ctx.save()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.secondary(scheme))

                        Button("Delete Exercise", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            )
            .onAppear {
                selectedMuscle = exercise.targetMuscle
                name = exercise.name
                sets = max(1, exercise.targetSets)
                if exercise.perSetReps.isEmpty {
                    customReps = Array(repeating: max(1, exercise.targetReps), count: sets)
                    defaultRepsForNewSets = max(1, exercise.targetReps)
                } else {
                    customReps = exercise.perSetReps
                    sets = max(1, customReps.count)
                    defaultRepsForNewSets = customReps.last ?? 10
                }
                syncCustomArray(to: sets)
            }
            .confirmationDialog(
                "Delete exercise?",
                isPresented: $showDeleteConfirm
            ) {
                Button("Delete", role: .destructive) {
                    if let idx = day.exercises.firstIndex(where: { $0.id == exercise.id }) {
                        day.exercises.remove(at: idx)
                        try? ctx.save()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .navigationTitle("Exercise")
            .navigationBarTitleDisplayMode(.inline)
    }

    private func syncCustomArray(to newSets: Int) {
        if customReps.count < newSets {
            customReps.append(contentsOf: Array(repeating: max(1, defaultRepsForNewSets), count: newSets - customReps.count))
        } else if customReps.count > newSets {
            customReps = Array(customReps.prefix(newSets))
        }
    }
    private var groupedMuscles: [String: [TargetMuscle]] {
        Dictionary(grouping: TargetMuscle.allCases, by: { $0.group })
    }
}
