//
//  ProgramDetailView.swift
//  GymLog
//

import SwiftUI
import SwiftData

struct ProgramDetailView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State var program: Program

    // Add Day Sheet
    @State private var showAddDaySheet = false
    @State private var newDayTitle = ""

    // Rename Program
    @State private var showRenameSheet = false
    @State private var tempProgramName = ""

    // Delete Program confirm
    @State private var showDeleteProgramConfirm = false

    var body: some View {
        ZStack { AppBackground() }
            .overlay(
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(program.name)
                            .font(.title2.bold())
                            .foregroundStyle(AppColors.neutral(scheme))
                        Spacer()
                        Toggle("Active", isOn: Binding(
                            get: { program.isActive },
                            set: { program.isActive = $0; ctx.saveOrLog() }
                        ))
                        .labelsHidden()
                    }

                    // Days only
                    List {
                        ForEach(program.days.sorted(by: { $0.orderIndex < $1.orderIndex })) { day in
                            NavigationLink(destination: DayDetailView(program: program, day: day)) {
                                HStack {
                                    Text(day.title)
                                        .foregroundStyle(AppColors.neutral(scheme))
                                    Spacer()
                                }
                            }
                            .listRowBackground(AppColors.primary(scheme).opacity(0.4))
                        }
                    }
                    .scrollContentBackground(.hidden)

                    HStack(spacing: 12) {
                        Button("Rename Program") {
                            tempProgramName = program.name
                            showRenameSheet = true
                        }
                        .buttonStyle(.bordered)
                        .tint(AppColors.accent(scheme))

                        Button("Add Day") {
                            newDayTitle = ""
                            showAddDaySheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.secondary(scheme))

                        Spacer()

                        Button("Delete Program", role: .destructive) {
                            showDeleteProgramConfirm = true
                        }
                    }
                }
                .padding()
            )
            .sheet(isPresented: $showAddDaySheet) {
                AddDaySheet(newTitle: $newDayTitle) {
                    let next = (program.days.map { $0.orderIndex }.max() ?? -1) + 1
                    let d = ProgramDay(orderIndex: next, title: newDayTitle.isEmpty ? "Day \(next + 1)" : newDayTitle)
                    program.days.append(d)
                    ctx.saveOrLog()
                }
                .presentationDetents([.fraction(0.3)])
            }
            .sheet(isPresented: $showRenameSheet) {
                RenameProgramSheet(
                    title: "Rename Program",
                    value: $tempProgramName
                ) {
                    let name = tempProgramName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        program.name = name
                        ctx.saveOrLog()
                    }
                }
                .presentationDetents([.fraction(0.3)])
            }
            .confirmationDialog(
                "Delete program?",
                isPresented: $showDeleteProgramConfirm
            ) {
                Button("Delete", role: .destructive) {
                    ctx.delete(program)
                    ctx.saveOrLog()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the program, its days, and exercises.")
            }
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AddDaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Binding var newTitle: String
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Day")
                .font(.headline)
                .foregroundStyle(AppColors.neutral(scheme))
            TextField("Day title", text: $newTitle)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Add") { onAdd(); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.secondary(scheme))
            }
        }
        .padding()
        .background(AppColors.primary(scheme).opacity(0.25))
    }
}

private struct RenameProgramSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let title: String
    @Binding var value: String
    var onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.neutral(scheme))
            TextField("Program name", text: $value)
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

