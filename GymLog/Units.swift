// Units.swift
// GymLog

import Foundation
import SwiftUI

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg, lb
    var id: String { rawValue }
    var label: String { self == .kg ? "kg" : "lb" }
    var step: Double { self == .kg ? 2.5 : 5.0 }
}

struct UnitsSettings {
    private static let key = "weightUnit"

    static var weightUnitRaw: String {
        get { UserDefaults.standard.string(forKey: key) ?? WeightUnit.kg.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static var currentUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .kg
    }

    static func convertToCurrent(fromKg value: Double) -> Double {
        switch currentUnit {
        case .kg: return value
        case .lb: return value * 2.2046226218
        }
    }

    static func convertToKg(fromCurrent value: Double) -> Double {
        switch currentUnit {
        case .kg: return value
        case .lb: return value / 2.2046226218
        }
    }

    /// Rounds a kg value to a sensible increment in the current unit (2.5 kg or 5 lb), then returns the display value in the current unit.
    static func roundedDisplay(_ valueInKg: Double) -> Double {
        let unit = currentUnit
        let raw = convertToCurrent(fromKg: valueInKg)
        let step = unit.step
        let rounded = (raw / step).rounded() * step
        return rounded
    }

    /// Formats a kg value for display in the current unit.
    static func format(_ valueInKg: Double) -> String {
        let unit = currentUnit
        let raw = convertToCurrent(fromKg: valueInKg)
        if unit == .kg {
            let v = (raw * 2).rounded() / 2 // nearest 0.5
            return v == floor(v) ? String(format: "%.0f", v) : String(format: "%.1f", v)
        } else {
            return String(format: "%.0f", raw.rounded())
        }
    }
}
