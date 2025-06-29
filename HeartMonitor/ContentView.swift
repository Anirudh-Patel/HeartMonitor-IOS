//
//  ContentView.swift
//  HeartMonitor
//
//  Created by Anirudh Patel on 6/15/25.
//


import CoreData

import SwiftUI
import Charts
import HealthKit

// Data model for RR intervals
struct RRIntervalData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    
    // Color based on health range (0.6-1.0 seconds is healthy)
    var color: Color {
        let healthiness = 1.0 - abs(value - 0.8) / 0.4 // 0.8 is middle of healthy range
        
        if healthiness >= 1.0 {
            return .green // Perfectly healthy
        } else if healthiness <= 0.0 {
            return .red // Outside healthy range
        } else {
            // Gradient between red and green
            return Color(
                red: 1.0 - healthiness,
                green: healthiness,
                blue: 0.0
            )
        }
    }
}

// Class to manage and simulate RR interval data
class RRIntervalViewModel: ObservableObject {
    @Published var intervals: [RRIntervalData] = []
    private var timer: Timer?
    private var counter: Double = 0
    
    init() {
        // Initialize with 60 seconds of data
        let now = Date()
        for i in 0..<60 {
            let timestamp = now.addingTimeInterval(Double(-60 + i))
            let value = simulateValue(at: Double(i))
            intervals.append(RRIntervalData(timestamp: timestamp, value: value))
        }
    }
    
    func startSimulation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.counter += 1
            let newValue = self.simulateValue(at: self.counter)
            let newData = RRIntervalData(timestamp: Date(), value: newValue)
            
            // Add new data and remove oldest to maintain 60 seconds
            self.intervals.append(newData)
            if self.intervals.count > 60 {
                self.intervals.removeFirst()
            }
        }
    }
    
    func stopSimulation() {
        timer?.invalidate()
        timer = nil
    }
    
    private func simulateValue(at time: Double) -> Double {
        // Sine wave oscillating between 0.5 and 1.1 seconds
        // This will show both healthy and unhealthy ranges
        let baseValue = 0.8 // Center of healthy range
        let amplitude = 0.3 // Oscillation amplitude
        let period = 30.0 // Complete cycle every 30 seconds
        
        return baseValue + amplitude * sin(2 * .pi * time / period)
    }
    
    deinit {
        stopSimulation()
    }
}

struct ContentView: View {
    @StateObject private var viewModel = RRIntervalViewModel()
    @State private var selectedTab = 0
    @State private var isAuthorized = false
    @State private var errorMessage: String?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // First Tab - RR Interval Monitoring
            RRIntervalView(viewModel: viewModel, isAuthorized: $isAuthorized, errorMessage: $errorMessage)
                .tabItem {
                    Label("Monitor", systemImage: "heart.fill")
                }
                .tag(0)
            
            // Placeholder tabs for future implementation
            Text("History View")
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(1)
            
            Text("Settings View")
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
            
            Text("Profile View")
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .accentColor(.green) // Highlight color for selected tab
        .preferredColorScheme(.dark) // Dark mode
        .onAppear {
            viewModel.startSimulation()
            checkHealthKitAuthorization()
        }
        .onDisappear {
            viewModel.stopSimulation()
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
            }
        }
    }
}

struct RRIntervalView: View {
    @ObservedObject var viewModel: RRIntervalViewModel
    @Binding var isAuthorized: Bool
    @Binding var errorMessage: String?
    
    var body: some View {
        VStack {
            Text("RR Interval Monitor")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            // Chart area
            chartView
                .frame(height: 300)
                .padding()
            
            // Current value display
            if let latestPoint = viewModel.intervals.last {
                HStack {
                    Text("Current: ")
                        .fontWeight(.medium)
                    
                    Text(String(format: "%.2f s", latestPoint.value))
                        .fontWeight(.bold)
                        .foregroundColor(latestPoint.color)
                    
                    Text(healthStatus(for: latestPoint.value))
                        .fontWeight(.medium)
                        .foregroundColor(latestPoint.color)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(10)
            }
            
            Spacer()
            
            // Fetch button
            Button(action: {
                if isAuthorized {
                    // Refresh data from HealthKit
                    fetchRRIntervals()
                } else {
                    // Request authorization
                    requestHealthKitAuthorization()
                }
            }) {
                Text(isAuthorized ? "Refresh Data" : "Fetch RR Intervals")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(15)
                    .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .background(Color(UIColor.systemBackground))
    }
    
    var chartView: some View {
        Chart {
            // Create a gradient area chart underneath for better visualization
            ForEach(viewModel.intervals) { interval in
                AreaMark(
                    x: .value("Time", interval.timestamp),
                    y: .value("RR Interval", interval.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        stops: [
                            Gradient.Stop(color: .red, location: 0),       // 0.4 (too low)
                            Gradient.Stop(color: .orange, location: 0.25), // 0.5 (approaching healthy)
                            Gradient.Stop(color: .green, location: 0.5),   // 0.8 (healthy middle)
                            Gradient.Stop(color: .orange, location: 0.75), // 1.1 (approaching too high)
                            Gradient.Stop(color: .red, location: 1)        // 1.2 (too high)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .opacity(0.2) // Make it semi-transparent
            }
            
            // Main line with gradient
            ForEach(viewModel.intervals) { interval in
                LineMark(
                    x: .value("Time", interval.timestamp),
                    y: .value("RR Interval", interval.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        stops: [
                            Gradient.Stop(color: .red, location: 0),       // 0.4 (too low)
                            Gradient.Stop(color: .orange, location: 0.25), // 0.5 (approaching healthy)
                            Gradient.Stop(color: .green, location: 0.5),   // 0.8 (healthy middle)
                            Gradient.Stop(color: .orange, location: 0.75), // 1.1 (approaching too high)
                            Gradient.Stop(color: .red, location: 1)        // 1.2 (too high)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 3))
            }
            
            // Add reference lines for healthy range
            RuleMark(y: .value("Min Healthy", 0.6))
                .foregroundStyle(.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            
            RuleMark(y: .value("Max Healthy", 1.0))
                .foregroundStyle(.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            
            // Add a special point mark for the latest data point
            if let latestPoint = viewModel.intervals.last {
                PointMark(
                    x: .value("Latest", latestPoint.timestamp),
                    y: .value("Value", latestPoint.value)
                )
                .foregroundStyle(latestPoint.color)
                .symbolSize(150) // Larger dot for the latest point
            }
        }
        .chartYScale(domain: 0.4...1.2)
        .chartXAxis {
            AxisMarks(values: .stride(by: 10)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.minute().second())
            }
        }
        .chartYAxis {
            AxisMarks(values: .stride(by: 0.2)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.1f", doubleValue))
                    }
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func healthStatus(for value: Double) -> String {
        if value >= 0.6 && value <= 1.0 {
            return "Healthy"
        } else if value < 0.6 {
            return "Below Range"
        } else {
            return "Above Range"
        }
    }
    
    private func requestHealthKitAuthorization() {
        HealthKitManager.shared.requestAuthorization { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isAuthorized = true
                    self.fetchRRIntervals()
                } else {
                    self.errorMessage = error?.localizedDescription ?? "Failed to authorize HealthKit"
                }
            }
        }
    }
    
    private func fetchRRIntervals() {
        HealthKitManager.shared.fetchLatestRRIntervals { intervals, error in
            DispatchQueue.main.async {
                if let intervals = intervals, !intervals.isEmpty {
                    // Convert HealthKit data to our model
                    let now = Date()
                    let newData = intervals.enumerated().map { index, value in
                        RRIntervalData(
                            timestamp: now.addingTimeInterval(Double(-intervals.count + index)),
                            value: value
                        )
                    }
                    
                    // If we have real data, replace the simulated data
                    if !newData.isEmpty {
                        self.viewModel.intervals = newData
                    }
                    
                    self.errorMessage = nil
                } else {
                    // If no data, continue with simulation
                    self.errorMessage = error?.localizedDescription ?? "No RR interval data available"
                }
            }
        }
    }
}

struct GlowingDotModifier: ViewModifier {
    var color: Color
    var radius: CGFloat = 10
    
    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    Circle()
                        .fill(color)
                        .blur(radius: radius)
                        .opacity(0.3)
                    
                    Circle()
                        .fill(color)
                        .blur(radius: radius/2)
                        .opacity(0.3)
                    
                    Circle()
                        .fill(color)
                        .padding(4)
                }
            )
    }
}

extension View {
    func glowingDot(color: Color, radius: CGFloat = 10) -> some View {
        self.modifier(GlowingDotModifier(color: color, radius: radius))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
