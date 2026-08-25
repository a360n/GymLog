//
//  ProgramsView.swift
//  GymLog
//

import Foundation
import SwiftUI
import SwiftData

struct ProgramsView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    @Query(sort: [SortDescriptor(\Program.name, order: .forward)]) private var programs: [Program]

    // Delete Program
    @State private var showDeleteProgramConfirm = false
    @State private var programToDelete: Program?

    // Create Program
    @State private var showCreateProgramSheet = false
    @State private var newProgramName = ""
    @State private var newProgramMonths = 6

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Programs")
                            .font(.title.bold())
                            .foregroundStyle(AppColors.neutral(scheme))
                        Spacer()
                        Button {
                            newProgramName = ""
                            newProgramMonths = 6
                            showCreateProgramSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(AppColors.accent(scheme))
                    }

                    List {
                        ForEach(programs) { p in
                            NavigationLink(destination: ProgramDetailView(program: p)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(p.name)
                                        .foregroundStyle(AppColors.neutral(scheme))
                                    Text(p.isActive ? "Active" : "Inactive")
                                        .font(.caption)
                                        .foregroundStyle(p.isActive ? AppColors.secondary(scheme) : .secondary)
                                }
                            }
                            .listRowBackground(AppColors.primary(scheme).opacity(0.5))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    programToDelete = p
                                    showDeleteProgramConfirm = true
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .confirmationDialog(
                "Delete program?",
                isPresented: $showDeleteProgramConfirm,
                presenting: programToDelete
            ) { p in
                Button("Delete", role: .destructive) {
                    ctx.delete(p)
                    ctx.saveOrLog()
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This will remove the program, its days, and exercises.")
            }
            .sheet(isPresented: $showCreateProgramSheet) {
                CreateProgramSheet(
                    newName: $newProgramName,
                    months: $newProgramMonths
                ) {
                    let p = Program(name: newProgramName.isEmpty ? "New Program" : newProgramName,
                                    startDate: Date(),
                                    durationMonths: newProgramMonths,
                                    isActive: programs.isEmpty)
                    ctx.insert(p)
                    ctx.saveOrLog()
                }
                .presentationDetents([.fraction(0.4)])
            }
        }
    }
}

struct CreateProgramSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Binding var newName: String
    @Binding var months: Int
    var onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create Program")
                .font(.headline)
                .foregroundStyle(AppColors.neutral(scheme))
            TextField("Program name", text: $newName)
                .textFieldStyle(.roundedBorder)
            Stepper("Duration: \(months) months", value: $months, in: 1...24)
            HStack {
                Spacer()
                Button("Create") { onCreate(); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.secondary(scheme))
            }
        }
        .padding()
        .background(AppColors.primary(scheme).opacity(0.25))
    }
}
