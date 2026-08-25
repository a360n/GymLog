//
//  Theme.swift
//  GymLog
//
//  Created by Ali Al-Khazali on 9/9/25.
//

import Foundation
import SwiftUI

import SwiftUI

enum Palette {
    // Dark mode (sporty, high-contrast)
    static let d_bg        = Color(hex: "#0B0F14")     // Deep sport black-blue
    static let d_primary   = Color(hex: "#121A24")     // Slate surface for cards
    static let d_secondary = Color(hex: "#30D158")     // Neon green (energy)
    static let d_accent    = Color(hex: "#0A84FF")     // Electric blue (CTA)
    static let d_neutral   = Color(hex: "#E6EDF3")     // Primary text on dark

    // Light mode (clean, energetic)
    static let l_bg        = Color(hex: "#F8FAFC")     // Near-white with a cool tint
    static let l_primary   = Color(hex: "#E6F0FF")     // Light blue surface for cards
    static let l_secondary = Color(hex: "#34C759")     // Bright green (energy)
    static let l_accent    = Color(hex: "#0A84FF")     // Electric blue (CTA)
    static let l_neutral   = Color(hex: "#111827")     // Primary text on light
}

struct AppColors {
    static func primary(_ scheme: ColorScheme)   -> Color { scheme == .dark ? Palette.d_primary   : Palette.l_primary }
    static func secondary(_ scheme: ColorScheme) -> Color { scheme == .dark ? Palette.d_secondary : Palette.l_secondary }
    static func accent(_ scheme: ColorScheme)    -> Color { scheme == .dark ? Palette.d_accent    : Palette.l_accent }
    static func neutral(_ scheme: ColorScheme)   -> Color { scheme == .dark ? Palette.d_neutral   : Palette.l_neutral }
    static func background(_ scheme: ColorScheme)-> Color { scheme == .dark ? Palette.d_bg        : Palette.l_bg }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        // Support #RGB, #RRGGBB, #AARRGGBB
        if s.count == 3 {
            // e.g. F0A -> FF00AA
            s = s.map { "\($0)\($0)" }.joined()
        }

        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)

        var a: UInt64 = 255
        var r: UInt64 = 0
        var g: UInt64 = 0
        var b: UInt64 = 0

        if s.count == 8 {
            a = (v >> 24) & 0xFF
            r = (v >> 16) & 0xFF
            g = (v >> 8)  & 0xFF
            b =  v        & 0xFF
        } else if s.count == 6 {
            r = (v >> 16) & 0xFF
            g = (v >> 8)  & 0xFF
            b =  v        & 0xFF
        } else {
            // Fallback to black if format is unexpected
            r = 0; g = 0; b = 0; a = 255
        }

        self.init(.sRGB,
                  red:   Double(r) / 255.0,
                  green: Double(g) / 255.0,
                  blue:  Double(b) / 255.0,
                  opacity: Double(a) / 255.0)
    }
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        AppColors.background(scheme).ignoresSafeArea().allowsHitTesting(false)
    }
}
