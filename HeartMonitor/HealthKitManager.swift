//
//  HealthKitManager.swift
//  HeartMonitor
//
//  Created by Anirudh Patel on 6/15/25.
//


import Foundation
import HealthKit

class HealthKitManager {
    // Singleton instance
    static let shared = HealthKitManager()
    
    // The HealthKit store
    let healthStore = HKHealthStore()
    
    // Check if HealthKit is available on this device
    var isHealthKitAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    // HRV type for accessing RR intervals
    let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    
    // Heart rate type
    let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    
    // Initialize with private access to enforce singleton pattern
    private init() {}
    
    // Request authorization to access HealthKit data
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // Define the types we want to read from HealthKit
        let typesToRead: Set<HKObjectType> = [
            heartRateType,
            hrvType,
            HKObjectType.categoryType(forIdentifier: .irregularHeartRhythmEvent)!
        ]
        
        // Define an empty set for types to share (cannot be nil)
        let typesToShare: Set<HKSampleType> = []
        
        // Request authorization
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            completion(success, error)
        }
    }
    
    // Fetch the latest RR interval data
    func fetchLatestRRIntervals(completion: @escaping ([Double]?, Error?) -> Void) {
        // Create a predicate for the last 24 hours
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        // Sort descriptor to get the most recent samples first
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        // Create the query
        let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: 10, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let samples = samples as? [HKQuantitySample], error == nil else {
                completion(nil, error)
                return
            }
            
            // Process the samples to extract RR intervals
            // Note: This is a simplified approach - actual RR intervals require more processing
            let rrIntervals = samples.map { sample in
                return sample.quantity.doubleValue(for: HKUnit.second())
            }
            
            completion(rrIntervals, nil)
        }
        
        // Execute the query
        healthStore.execute(query)
    }
}
