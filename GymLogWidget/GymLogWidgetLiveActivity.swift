//
//  GymLogWidgetLiveActivity.swift
//  GymLogWidget
//
//  Created by Ali Al-Khazali on 9/10/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct GymLogWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct GymLogWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymLogWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension GymLogWidgetAttributes {
    fileprivate static var preview: GymLogWidgetAttributes {
        GymLogWidgetAttributes(name: "World")
    }
}

extension GymLogWidgetAttributes.ContentState {
    fileprivate static var smiley: GymLogWidgetAttributes.ContentState {
        GymLogWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: GymLogWidgetAttributes.ContentState {
         GymLogWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: GymLogWidgetAttributes.preview) {
   GymLogWidgetLiveActivity()
} contentStates: {
    GymLogWidgetAttributes.ContentState.smiley
    GymLogWidgetAttributes.ContentState.starEyes
}
