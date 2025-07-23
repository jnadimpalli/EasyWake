// LambdaRateLimiter.swift

import Foundation

// MARK: - Lambda Rate Limiter
@MainActor
class LambdaRateLimiter: ObservableObject {
    static let shared = LambdaRateLimiter()
    
    // Configuration
    private let maxRequestsPerAlarmPerInterval = 1
    private let intervalMinutes: TimeInterval = 15 // 15 minutes
    private let batchingWindowSeconds: TimeInterval = 2 // 2 seconds to collect batch requests
    
    // State
    private var requestHistory: [UUID: [Date]] = [:] // AlarmID -> [Request timestamps]
    private var pendingRequests: [(UUID, Date)] = [] // Queue of (AlarmID, RequestTime)
    private var batchTimer: Timer?
    
    // MARK: - Public Methods
    
    /// Check if a request can be made for an alarm
    func canMakeRequest(for alarmId: UUID) -> Bool {
        cleanupOldRequests()
        
        guard let history = requestHistory[alarmId] else {
            return true // No history, can make request
        }
        
        let recentRequests = history.filter { request in
            Date().timeIntervalSince(request) < (intervalMinutes * 60)
        }
        
        return recentRequests.count < maxRequestsPerAlarmPerInterval
    }
    
    /// Record a request for rate limiting
    func recordRequest(for alarmId: UUID) {
        cleanupOldRequests()
        
        if requestHistory[alarmId] == nil {
            requestHistory[alarmId] = []
        }
        
        requestHistory[alarmId]?.append(Date())
        
        print("[RATE-LIMITER] Request recorded for alarm: \(alarmId)")
        print("[RATE-LIMITER] Total requests in last \(Int(intervalMinutes)) minutes: \(requestHistory[alarmId]?.count ?? 0)")
    }
    
    /// Queue a request for batching
    func queueRequest(for alarmId: UUID) -> Bool {
        guard canMakeRequest(for: alarmId) else {
            print("[RATE-LIMITER] Request denied for alarm: \(alarmId) - Rate limit exceeded")
            return false
        }
        
        pendingRequests.append((alarmId, Date()))
        startBatchTimer()
        return true
    }
    
    /// Get all pending requests for batch processing
    func getBatchedRequests() -> [UUID] {
        let requests = pendingRequests.map { $0.0 }
        pendingRequests.removeAll()
        
        // Record all requests
        for alarmId in requests {
            recordRequest(for: alarmId)
        }
        
        // Remove duplicates
        let uniqueRequests = Array(Set(requests))
        
        print("[RATE-LIMITER] Batching \(uniqueRequests.count) unique requests from \(requests.count) total")
        return uniqueRequests
    }
    
    /// Get time until next allowed request for an alarm
    func timeUntilNextRequest(for alarmId: UUID) -> TimeInterval? {
        cleanupOldRequests()
        
        guard let history = requestHistory[alarmId], !history.isEmpty else {
            return nil // Can make request now
        }
        
        let recentRequests = history.filter { request in
            Date().timeIntervalSince(request) < (intervalMinutes * 60)
        }
        
        if recentRequests.count >= maxRequestsPerAlarmPerInterval {
            // Find the oldest request in the window
            if let oldestRequest = recentRequests.min() {
                let timeElapsed = Date().timeIntervalSince(oldestRequest)
                let timeRemaining = (intervalMinutes * 60) - timeElapsed
                return max(0, timeRemaining)
            }
        }
        
        return nil // Can make request now
    }
    
    // MARK: - Private Methods
    
    private func cleanupOldRequests() {
        let cutoffTime = Date().addingTimeInterval(-(intervalMinutes * 60))
        
        for (alarmId, history) in requestHistory {
            let recentRequests = history.filter { $0 > cutoffTime }
            if recentRequests.isEmpty {
                requestHistory.removeValue(forKey: alarmId)
            } else {
                requestHistory[alarmId] = recentRequests
            }
        }
    }
    
    private func startBatchTimer() {
        // Cancel existing timer
        batchTimer?.invalidate()
        
        // Start new timer
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchingWindowSeconds, repeats: false) { [weak self] _ in
            self?.processBatchedRequests()
        }
    }
    
    private func processBatchedRequests() {
        // This will be called by the service that actually makes Lambda calls
        NotificationCenter.default.post(
            name: .lambdaBatchReady,
            object: nil
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let lambdaBatchReady = Notification.Name("lambdaBatchReady")
}

// MARK: - Usage Statistics
extension LambdaRateLimiter {
    struct UsageStatistics {
        let totalRequests: Int
        let requestsInLastHour: Int
        let requestsInLastDay: Int
        let averageRequestsPerAlarmPerHour: Double
    }
    
    func getUsageStatistics() -> UsageStatistics {
        cleanupOldRequests()
        
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let oneDayAgo = now.addingTimeInterval(-86400)
        
        var totalRequests = 0
        var requestsInLastHour = 0
        var requestsInLastDay = 0
        
        for (_, history) in requestHistory {
            totalRequests += history.count
            requestsInLastHour += history.filter { $0 > oneHourAgo }.count
            requestsInLastDay += history.filter { $0 > oneDayAgo }.count
        }
        
        let averageRequestsPerAlarmPerHour = requestHistory.isEmpty ? 0 :
            Double(requestsInLastHour) / Double(requestHistory.count)
        
        return UsageStatistics(
            totalRequests: totalRequests,
            requestsInLastHour: requestsInLastHour,
            requestsInLastDay: requestsInLastDay,
            averageRequestsPerAlarmPerHour: averageRequestsPerAlarmPerHour
        )
    }
}
