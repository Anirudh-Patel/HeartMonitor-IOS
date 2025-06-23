//
//  ContentView.swift
//  HeartMonitor
//
//  Created by Anirudh Patel on 6/15/25.
//


import CoreData

import SwiftUI
import HealthKit

struct ContentView: View {
    @State private var rrIntervals: [Double] = []
    @State private var isAuthorized = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                }
                
                if !isAuthorized {
                    Button("Request HealthKit Access") {
                        requestHealthKitAuthorization()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                } else {
                    Text("RR Intervals (seconds)")
                        .font(.headline)
                        .padding(.top)
                    
                    if rrIntervals.isEmpty {
                        Text("No data available")
                            .foregroundColor(.gray)
                            .padding()
                        
                        Button("Fetch RR Intervals") {
                            fetchRRIntervals()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    } else {
                        List {
                            ForEach(rrIntervals.indices, id: \.self) { index in
                                Text("Interval \(index + 1): \(rrIntervals[index], specifier: "%.4f") s")
                            }
                        }
                        .refreshable {
                            fetchRRIntervals()
                        }
                    }
                }
            }
            .navigationTitle("Heart Monitor")
            .onAppear {
                checkHealthKitAuthorization()
            }
        }
    }
    
    private func checkHealthKitAuthorization() {
        // Check if HealthKit is available
        if !HealthKitManager.shared.isHealthKitAvailable {
            errorMessage = "HealthKit is not available on this device"
            return
        }
        
        // Create empty set for types to share (cannot be nil)
        let typesToShare: Set<HKSampleType> = []
        
        // Create set for types to read
        let typesToRead: Set<HKObjectType> = [HealthKitManager.shared.hrvType]
        
        // Check authorization status
        HealthKitManager.shared.healthStore.getRequestStatusForAuthorization(
            toShare: typesToShare,
            read: typesToRead
        ) { status, _ in
            DispatchQueue.main.async {
                isAuthorized = status == .unnecessary
                if isAuthorized {
                    fetchRRIntervals()
                }
            }
        }
    }
    
    private func requestHealthKitAuthorization() {
        HealthKitManager.shared.requestAuthorization { success, error in
            DispatchQueue.main.async {
                if success {
                    isAuthorized = true
                    fetchRRIntervals()
                } else {
                    errorMessage = error?.localizedDescription ?? "Failed to authorize HealthKit"
                }
            }
        }
    }
    
    private func fetchRRIntervals() {
        HealthKitManager.shared.fetchLatestRRIntervals { intervals, error in
            DispatchQueue.main.async {
                if let intervals = intervals {
                    self.rrIntervals = intervals
                    self.errorMessage = nil
                } else {
                    self.errorMessage = error?.localizedDescription ?? "Failed to fetch RR intervals"
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.colorScheme, .light)
            .previewDevice("iPhone 14") // Specify an iPhone device
    }
}
