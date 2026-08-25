//
//  ContentView.swift
//  GymLog
//
//  Created by Ali Al-Khazali on 9/9/25.
//

import SwiftUI
import SwiftData
import Charts


struct ContentView: View {
    // MARK: Env / State
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme

    @AppStorage("useLightMode") private var useLightMode: Bool = false
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @Binding var deeplinkURL: URL?

    @Query(sort: [SortDescriptor(\Program.name, order: .forward)])
    private var programs: [Program]

    @State private var activeProgram: Program?
    @State private var startProgram: Program?   // ← من أجل navigationDestination
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppBackground()

                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let program = activeProgram {
                        NavigationLink(destination: ProgramDetailView(program: program)) {
                            ProgramCard(program: program)
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: AnalyticsView(program: program)) {
                            MiniAnalyticsView(program: program)
                                .frame(height: 160)
                                .padding(.vertical, 6)
                                .background(AppColors.primary(scheme).opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        emptyState
                    }

                    Spacer(minLength: 0)
                }
                .padding()

                floatingButtons
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)

            // ✅ ضع الوجهة هنا داخل الـ NavigationStack
            .navigationDestination(item: $startProgram) { p in
                TodayWorkoutView(program: p)
            }
        }
        // MARK: Hooks
        .onAppear { pickActiveProgram() }
        .onChange(of: programs) { _, _ in pickActiveProgram() }
        .onChange(of: deeplinkURL) { _, url in
            guard let url else { return }
            handleDeeplink(url)
        }

    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("GymLog")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColors.neutral(scheme))

            Spacer()

            Picker("Unit", selection: $weightUnitRaw) {
                Text("kg").tag(WeightUnit.kg.rawValue)
                Text("lb").tag(WeightUnit.lb.rawValue)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)

            Toggle(isOn: $useLightMode) { Text("Light") }
                .labelsHidden()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No programs yet")
                .font(.title3.bold())
                .foregroundStyle(AppColors.neutral(scheme))
            Text("Tap + to create your first training plan.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppColors.primary(scheme).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var floatingButtons: some View {
        VStack(alignment: .trailing, spacing: 12) {
            NavigationLink(destination: ProgramsView()) {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .padding(18)
                    .background(AppColors.accent(scheme))
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                    .shadow(radius: 8)
            }

            if let program = activeProgram {
                Button {
                    // بدل الـ NavigationLink المخفي القديم:
                    startProgram = program
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title2.weight(.bold))
                        .padding(22)
                        .background(AppColors.secondary(scheme))
                        .foregroundStyle(.black)
                        .clipShape(Circle())
                        .shadow(radius: 8)
                }
            }
        }
        .padding(.trailing, 18)
        .padding(.bottom, 22)
    }

    // MARK: - Helpers

    private func pickActiveProgram() {
        activeProgram = (programs.first { $0.isActive }) ?? programs.first
    }

    private func handleDeeplink(_ url: URL) {
        if url.host == "start-today" || url.absoluteString == "gymlog://start-today" {
            if let p = activeProgram ?? programs.first(where: { $0.isActive }) ?? programs.first {
                startProgram = p
            }
            return
        }
        // أمثلة مستقبلية:
        // gymlog://exercise?id=<uuid>
    }
}



struct ProgramCard: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    let program: Program

    var body: some View {
        let endDate = Calendar.current.date(byAdding: .month, value: program.durationMonths, to: program.startDate) ?? program.startDate
        let completed = ((try? ctx.fetch(FetchDescriptor<WorkoutSession>())) ?? [])
            .filter { $0.programId == program.id && $0.isCompleted }
            .count

        return VStack(alignment: .leading, spacing: 8) {
            Text(program.name)
                .font(.title2.bold())
                .foregroundStyle(AppColors.neutral(scheme))
            Text("From: \(program.startDate.formatted(date: .abbreviated, time: .omitted))  →  To: \(endDate.formatted(date: .abbreviated, time: .omitted))")
                .foregroundStyle(.secondary)
            Text("Completed sessions: \(completed)")
                .foregroundStyle(AppColors.secondary(scheme))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.primary(scheme).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

