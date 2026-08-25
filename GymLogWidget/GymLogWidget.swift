//
//  GymLogWidget.swift
//  GymLogWidget
//
//  Created by Ali Al-Khazali on 9/10/25.
//


import WidgetKit
import SwiftUI



// بيانات الإدخال للويدجت
struct TodayEntry: TimelineEntry {
    let date: Date
    let title: String
    let exercisesCount: Int
    let deeplink: URL
}

// مزوّد البيانات
struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), title: "Today’s Workout", exercisesCount: 0,
                   deeplink: URL(string: "gymlog://start-today")!)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> ()) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> ()) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry],
                                policy: .after(Date().addingTimeInterval(60*15)))
        completion(timeline)
    }

    private func loadEntry() -> TodayEntry {
        let defaults = UserDefaults(suiteName: SharedConstants.appGroupID)
        if let data = defaults?.data(forKey: SharedConstants.todaySummaryKey),
           let summary = try? JSONDecoder().decode(TodaySummary.self, from: data) {
            return TodayEntry(date: Date(),
                              title: summary.title,
                              exercisesCount: summary.exercisesCount,
                              deeplink: URL(string: "gymlog://start-today")!)
        }
        return TodayEntry(date: Date(),
                          title: "No workout",
                          exercisesCount: 0,
                          deeplink: URL(string: "gymlog://start-today")!)
    }}
struct TodayWidgetEntryView: View {
    var entry: TodayProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        // محتوى الويدجت
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("\(entry.exercisesCount) exercises")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Link(destination: entry.deeplink) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("Start")
                }
                .font(.subheadline.bold())
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(.quaternary, in: Capsule())
                .foregroundStyle(.primary)
            }
        }
        .padding(12)
        // ✅ خلفية مطلوبة للويدجت (iOS 17)
        .modifier(WidgetBackground())
    }
}

/// يوفّر خلفية مناسبة حسب النظام:
/// يوفر خلفية مناسبة حسب النظام، بدون containerRelativeShape
private struct WidgetBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.05, blue: 0.11),
                            Color(red: 0.04, green: 0.12, blue: 0.22)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        } else {
            content
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.05, blue: 0.11),
                            Color(red: 0.04, green: 0.12, blue: 0.22)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        }
    }
}
//@main
struct GymLogWidget: Widget {
    let kind: String = "GymLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetEntryView(entry: entry)
                .widgetURL(entry.deeplink)
        }
        .configurationDisplayName("Today’s Workout")
        .description("See today’s plan and start quickly.")
        .supportedFamilies([.systemSmall, .systemMedium]) // زد الحجم إن رغبت
    }
}
#if DEBUG
struct TodayWidget_Previews: PreviewProvider {
    static var previews: some View {
        TodayWidgetEntryView(
            entry: TodayEntry(
                date: .now,
                title: "Today’s Workout",
                exercisesCount: 4,
                deeplink: URL(string: "gymlog://start-today")!
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        TodayWidgetEntryView(
            entry: TodayEntry(
                date: .now,
                title: "Today’s Workout",
                exercisesCount: 4,
                deeplink: URL(string: "gymlog://start-today")!
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
#endif
