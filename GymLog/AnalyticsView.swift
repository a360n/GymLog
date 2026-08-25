//
//  AnalyticsView.swift
//  GymLog
//
//  Created by Ali Al-Khazali on 9/9/25.
//


import SwiftUI
import Charts
import SwiftData

struct AnalyticsView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var scheme
    let program: Program

    enum Metric: String, CaseIterable, Identifiable { case max = "Max", avg = "Average", volume = "Volume"; var id: String { rawValue } }

    @State private var showFilterSheet = false
    @State private var selectedGroup: String = TargetMuscle.chestMid.group
    @State private var selectedSpecific: TargetMuscle? = nil

    @State private var metric: Metric = .max
    @State private var useSmoothing: Bool = true
    @State private var range: RangePreset = .last8w

    struct Point: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    @State private var points: [Point] = []

    // Hover interaction
    @State private var hovered: Point?

    var body: some View {
        ZStack { AppBackground() }
            .overlay(
                VStack(alignment: .leading, spacing: 14) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Analytics")
                                .font(.title.bold())
                                .foregroundStyle(AppColors.neutral(scheme))
                            Text(subtitleText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { showFilterSheet = true } label: {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(AppColors.accent(scheme))
                    }

                    // Controls
                    HStack(spacing: 12) {
                        Picker("Metric", selection: $metric) {
                            ForEach(Metric.allCases) { m in Text(m.rawValue).tag(m) }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Smoothing", isOn: $useSmoothing)
                            .toggleStyle(.switch)

                        Picker("Range", selection: $range) {
                            ForEach(RangePreset.allCases) { r in Text(r.label).tag(r) }
                        }
                        .pickerStyle(.menu)
                    }

                    if points.isEmpty {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppColors.primary(scheme).opacity(0.2))
                            .overlay(Text("No data for selected filter").foregroundStyle(.secondary))
                            .frame(height: 260)
                    } else {
                        analyticsChart()
                    }
                    Spacer(minLength: 0)
                }
                .padding()
            )
            .onChange(of: metric) { _, _ in recompute() }
            .onChange(of: selectedGroup) { _, _ in recompute() }
            .onChange(of: selectedSpecific) { _, _ in recompute() }
            .onChange(of: range) { _, _ in recompute() }
            .onAppear { recompute() }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(
                    selectedGroup: $selectedGroup,
                    selectedSpecific: $selectedSpecific,
                    onApply: { recompute() }
                )
                .presentationDetents([.fraction(0.45)])
            }
    }
    @ViewBuilder
    private func analyticsChart() -> some View {
        let areaTop = AppColors.secondary(scheme).opacity(0.35)
        let areaBottom = AppColors.secondary(scheme).opacity(0.05)
        let lineColor = AppColors.accent(scheme)

        Chart(points) { p in
            AreaMark(x: .value("Date", p.date), y: .value("Value", p.value))
                .foregroundStyle(LinearGradient(colors: [areaTop, areaBottom], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(useSmoothing ? .monotone : .linear)

            LineMark(x: .value("Date", p.date), y: .value("Value", p.value))
                .lineStyle(.init(lineWidth: 2))
                .foregroundStyle(lineColor)
                .interpolationMethod(useSmoothing ? .monotone : .linear)

            PointMark(x: .value("Date", p.date), y: .value("Value", p.value))
                .symbolSize(20)
                .foregroundStyle(lineColor)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { v in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                AxisTick()
                AxisValueLabel {
                    if let d: Date = v.as(Date.self) { Text(dateTick(d)) }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                AxisTick()
                AxisValueLabel()
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(AppColors.primary(scheme).opacity(0.15))
                .cornerRadius(12)
        }
        .frame(height: 280)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if let plotAnchor = proxy.plotFrame {
                                    let plot: CGRect = geo[plotAnchor]
                                    let x: CGFloat = value.location.x - plot.origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        hovered = nearest(to: date)
                                    }
                                }
                            }
                            .onEnded { _ in
                                hovered = nil
                            }
                    )
            }
        }         .animation(.easeInOut(duration: 0.2), value: points)
    }
    private var subtitleText: String {
        if let s = selectedSpecific { return "\(selectedGroup) • \(s.display)" }
        return "\(selectedGroup) • All subdivisions"
    }

    // MARK: - Compute
    private func recompute() {
        Task {
            // Mapping exercise to muscle from the current program
            let nameToMuscle: [String: TargetMuscle] = program.days
                .flatMap { $0.exercises }
                .reduce(into: [String: TargetMuscle]()) { $0[$1.name] = $1.targetMuscle }

            let targetProgramId = program.id
            // Fetch completed sessions
            var descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate<WorkoutSession> { session in
                    session.programId == targetProgramId && session.isCompleted
                }
            )
            descriptor.sortBy = [SortDescriptor(\.date, order: .forward)]
            let filteredSessions = (try? ctx.fetch(descriptor)) ?? []

            // Determine date bounds
            let (start, end) = range.bounds(relativeTo: filteredSessions.map(\.date))
            let inRange = filteredSessions.filter { d in
                guard let s = start, let e = end else { return true }
                return (s...e).contains(d.date)
            }

            var out: [Point] = []

            for s in inRange {
                let entries = s.entries.filter { e in
                    let muscleRaw = e.targetMuscleAtLogRaw
                    if let raw = muscleRaw, let m = TargetMuscle(rawValue: raw) {
                        guard m.group == selectedGroup else { return false }
                        if let sp = selectedSpecific { return m == sp } else { return true }
                    }
                    // Fallback to mapping by name
                    guard let m = nameToMuscle[e.exerciseName] else { return false }
                    guard m.group == selectedGroup else { return false }
                    if let sp = selectedSpecific { return m == sp } else { return true }
                }

                let sets = entries.flatMap { $0.sets }
                guard !sets.isEmpty else { continue }

                let value: Double
                switch metric {
                case .max:
                    value = sets.map(\.weight).max() ?? 0
                case .avg:
                    let arr = sets.map(\.weight)
                    value = arr.reduce(0, +) / Double(arr.count)
                case .volume:
                    value = sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
                }

                if value > 0 {
                    out.append(Point(date: s.date, value: value))
                }
            }

            // Smoothing (rolling average of 5 points) if enabled
            let smoothed = useSmoothing ? rollingAverage(out, window: 5) : out
            
            await MainActor.run {
                self.points = smoothed
            }
        }
    }

    // MARK: - Helpers
    private func dateTick(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: d)
    }

    private func dateShort(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }

    private func nearest(to date: Date) -> Point? {
        guard !points.isEmpty else { return nil }
        return points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    private func rollingAverage(_ arr: [Point], window: Int) -> [Point] {
        guard window > 1, arr.count >= window else { return arr }
        var result: [Point] = []
        for i in 0..<arr.count {
            let lo = max(0, i - (window - 1))
            let slice = arr[lo...i]
            let avg = slice.map(\.value).reduce(0, +) / Double(slice.count)
            result.append(Point(date: arr[i].date, value: avg))
        }
        return result
    }

    enum RangePreset: String, CaseIterable, Identifiable {
        case last4w, last8w, last12w, all
        var id: String { rawValue }
        var label: String {
            switch self { case .last4w: "Last 4w"; case .last8w: "Last 8w"; case .last12w: "Last 12w"; case .all: "All" }
        }

        func bounds(relativeTo dates: [Date]) -> (Date?, Date?) {
            guard !dates.isEmpty else { return (nil, nil) }
            let cal = Calendar.current
            let end = dates.max()!
            switch self {
            case .last4w:  return (cal.date(byAdding: .weekOfYear, value: -4, to: end), end)
            case .last8w:  return (cal.date(byAdding: .weekOfYear, value: -8, to: end), end)
            case .last12w: return (cal.date(byAdding: .weekOfYear, value: -12, to: end), end)
            case .all:     return (dates.min()!, end)
            }
        }
    }
}
// MARK: - Filter Sheet

private struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @Binding var selectedGroup: String
    @Binding var selectedSpecific: TargetMuscle?
    var onApply: () -> Void

    private var groups: [String] {
        Array(Set(TargetMuscle.allCases.map { $0.group })).sorted()
    }
    private var musclesByGroup: [String: [TargetMuscle]] {
        Dictionary(grouping: TargetMuscle.allCases, by: { $0.group })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter")
                .font(.headline)
                .foregroundStyle(AppColors.neutral(scheme))

            // Muscle group selection
            Picker("Muscle group", selection: $selectedGroup) {
                ForEach(groups, id: \.self) { g in
                    Text(g).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedGroup) { _, _ in
                // Reset subdivision selection when group changes
                selectedSpecific = nil
            }

            // Subdivision selection (optional)
            Picker("Subdivision (optional)", selection: Binding(
                get: { selectedSpecific ?? TargetMuscle.allCases.first(where: { $0.group == selectedGroup }) },
                set: { newVal in
                    selectedSpecific = newVal
                }
            )) {
                Text("All subdivisions").tag(Optional<TargetMuscle>.none)
                ForEach((musclesByGroup[selectedGroup] ?? []).sorted(by: { $0.display < $1.display })) { m in
                    Text(m.display).tag(Optional(m))
                }
            }
            .pickerStyle(.menu)

            HStack {
                Spacer()
                Button("Apply") {
                    onApply()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.secondary(scheme))
            }
        }
        .padding()
        .background(AppColors.primary(scheme).opacity(0.25))
    }
}
