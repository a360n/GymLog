//
//  MiniAnalyticsView.swift
//  GymLog
//
//  Created by Ali Al-Khazali on 9/9/25.
//
import SwiftUI
import SwiftData
import Charts

struct MiniAnalyticsPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct MiniAnalyticsView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    let program: Program

    @State private var points: [MiniAnalyticsPoint] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress (last 10 sessions)")
                .font(.headline)
                .foregroundStyle(AppColors.neutral(scheme))
                .padding(.horizontal, 12)
                .padding(.top, 10)

            Chart(points) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Weight", p.value)
                )
                PointMark(
                    x: .value("Date", p.date),
                    y: .value("Weight", p.value)
                )
            }
            .frame(height: 120)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .onAppear(perform: load)
    }

    private func load() {
        // اجلب الجلسات المكتملة لهذا البرنامج مرتبة من الأقدم للأحدث
        let targetProgramId = program.id
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { session in
                session.programId == targetProgramId && session.isCompleted
            }
        )
        descriptor.sortBy = [SortDescriptor(\.date, order: .forward)]
        let done = (try? ctx.fetch(descriptor)) ?? []

        var pts: [MiniAnalyticsPoint] = []
        for s in done.suffix(10) {
            // استخدم العلاقة المباشرة
            let allSets = s.entries.flatMap { $0.sets }
            let maxW = allSets.map { $0.weight }.max() ?? 0
            pts.append(MiniAnalyticsPoint(date: s.date, value: maxW))
        }
        self.points = pts
    }
}
