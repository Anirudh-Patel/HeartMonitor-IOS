//
//  HeartMonitorApp.swift
//  HeartMonitor
//
//  Created by Anirudh Patel on 6/15/25.
//

import SwiftUI

@main
struct HeartMonitorApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
