//
//  SharedTypes.swift
//  GymLog
//
//  Created by Ali Al-Khazali on 9/10/25.
//

import Foundation
import WidgetKit

struct TodaySummary: Codable {
    let title: String
    let exercisesCount: Int
}

enum SharedConstants {
    static let appGroupID = "group.com.ali.GymLog"
    static let todaySummaryKey = "today_summary"
}

enum SharedUtils {
    /// يخزن ملخص اليوم ليستعمله الويدجت
    static func saveTodaySummary(title: String, exercises: Int) {
        let defaults = UserDefaults(suiteName: SharedConstants.appGroupID)
        let summary = TodaySummary(title: title, exercisesCount: exercises)
        if let data = try? JSONEncoder().encode(summary) {
            defaults?.set(data, forKey: SharedConstants.todaySummaryKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
