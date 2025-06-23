//
//  ContentView.swift
//  HeartMonitor WatchApp Watch App
//
//  Created by Anirudh Patel on 6/15/25.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @State private var isAuthorized = false
    @State private var heartRate: Double = 0
    @State private var errorMessage: String?
    @State private var isRequestingAuthorization = false
    
    var body: some View {
        VStack {
            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if !isAuthorized {
                if isRequestingAuthorization {
                    ProgressView("Requesting HealthKit Access...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Button("Request Access") {
                        requestHealthKitAuthorization()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                VStack {
                    Text("Heart Rate")
                        .font(.headline)
                    
                    Text("\(Int(heartRate)) BPM")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(heartRate > 0 ? .green : .gray)
                    
                    Button("Refresh") {
                        startHeartRateQuery()
                    }
                    .padding(.top)
                }
            }
        }
        .onAppear {
            checkHealthKitAuthorization()
        }
    }
    
    private func checkHealthKitAuthorization() {
        // Check if HealthKit is available
        if !HKHealthStore.isHealthDataAvailable() {
            errorMessage = "HealthKit not available"
            return
        }
        
        let healthStore = HKHealthStore()
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        // Create empty set for types to share (cannot be nil)
        let typesToShare: Set<HKSampleType> = []
        
        // Create set for types to read
        let typesToRead: Set<HKObjectType> = [heartRateType]
        
        healthStore.getRequestStatusForAuthorization(toShare: typesToShare, read: typesToRead) { status, _ in
            DispatchQueue.main.async {
                self.isAuthorized = status == .unnecessary
                if self.isAuthorized {
                    self.startHeartRateQuery()
                }
            }
        }
    }
    
    private func requestHealthKitAuthorization() {
        isRequestingAuthorization = true
        
        let healthStore = HKHealthStore()
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        // Create empty set for types to share (cannot be nil)
        let typesToShare: Set<HKSampleType> = []
        
        // Create set for types to read
        let typesToRead: Set<HKObjectType> = [heartRateType]
        
        healthStore.requestAuthorization(
            toShare: typesToShare,
            read: typesToRead
        ) { success, error in
            DispatchQueue.main.async {
                self.isRequestingAuthorization = false
                if success {
                    self.isAuthorized = true
                    self.startHeartRateQuery()
                } else {
                    self.errorMessage = error?.localizedDescription ?? "Authorization failed"
                }
            }
        }
    }
    
    private func startHeartRateQuery() {
        let healthStore = HKHealthStore()
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        // Get the most recent heart rate sample
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-3600),
            end: nil,
            options: .strictEndDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            guard let samples = samples as? [HKQuantitySample],
                  let sample = samples.first,
                  error == nil else {
                DispatchQueue.main.async {
                    self.errorMessage = error?.localizedDescription ?? "No data available"
                }
                return
            }
            
            DispatchQueue.main.async {
                self.heartRate = sample.quantity.doubleValue(
                    for: HKUnit.count().unitDivided(by: HKUnit.minute())
                )
                self.errorMessage = nil
            }
        }
        
        healthStore.execute(query)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
