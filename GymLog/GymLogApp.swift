//
//  GymLogApp.swift
//  GymLog
//
//  Created by Ali Al-Khazali on 9/9/25.
//

import SwiftUI
import SwiftData
import WidgetKit
@main
struct GymLogApp: App {
    @AppStorage("useLightMode") private var useLightMode: Bool = false
    @State private var deeplinkURL: URL?

    let container: ModelContainer
    
    init() {
        let schema = Schema([
            Program.self,
            ProgramDay.self,
            ProgramExercise.self,
            WorkoutSession.self,
            WorkoutEntry.self,
            WorkoutSet.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [config])

            #if DEBUG
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            if !isPreview {
                let ctx = ModelContext(container)
                let empty = (try? ctx.fetch(FetchDescriptor<Program>()))?.isEmpty ?? true
                if empty {
                    SeedDemo.run(into: ctx)
                }
            }
            #endif
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(deeplinkURL: $deeplinkURL)
                .preferredColorScheme(useLightMode ? .light : .dark)
                .onOpenURL { url in
                    deeplinkURL = url
                }
        }
        .modelContainer(container)
    }
}

