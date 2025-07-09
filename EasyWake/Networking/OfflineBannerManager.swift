import Foundation
import Combine

class OfflineBannerManager: ObservableObject {
    @Published var showOfflineBanner = false
    @Published var showReconnectionBanner = false
    private var hasShownOnCurrentDisconnect = false
    private var isCurrentlyOffline = false
    private var hasBeenOfflineThisSession = false
    private var lastNetworkChangeTime = Date()
    
    func handleNetworkChange(isConnected: Bool) {
        let now = Date()
        let timeSinceLastChange = now.timeIntervalSince(lastNetworkChangeTime)
        lastNetworkChangeTime = now
        
        print("=== Network Change ===")
        print("isConnected: \(isConnected)")
        print("Time since last change: \(String(format: "%.1f", timeSinceLastChange))s")
        print("Current state - isCurrentlyOffline: \(isCurrentlyOffline)")
        print("hasShownOnCurrentDisconnect: \(hasShownOnCurrentDisconnect)")
        print("hasBeenOfflineThisSession: \(hasBeenOfflineThisSession)")
        
        // Ignore rapid changes (less than 1 second apart)
        if timeSinceLastChange < 1.0 {
            print("Ignoring rapid network change (< 1s)")
            print("===================")
            return
        }
        
        if !isConnected && !isCurrentlyOffline {
            // Just went offline
            print("ACTION: Going offline - will show offline banner")
            isCurrentlyOffline = true
            hasBeenOfflineThisSession = true
            hasShownOnCurrentDisconnect = false
            
            // Dismiss any existing reconnection banner first
            if showReconnectionBanner {
                print("Dismissing existing reconnection banner")
                showReconnectionBanner = false
            }
            
            showOfflineBannerToUser()
            
        } else if isConnected && isCurrentlyOffline {
            // Just reconnected after being offline
            print("ACTION: Reconnected after being offline - will show reconnection banner")
            isCurrentlyOffline = false
            
            // Dismiss any existing offline banner first
            if showOfflineBanner {
                print("Dismissing existing offline banner")
                showOfflineBanner = false
            }
            
            showReconnectionBannerToUser()
        } else {
            print("No state change needed")
        }
        
        print("===================")
    }
    
    private func showOfflineBannerToUser() {
        guard !showOfflineBanner else {
            print("Offline banner already showing, skipping")
            return
        }
        
        print("SHOWING OFFLINE BANNER")
        hasShownOnCurrentDisconnect = true
        showOfflineBanner = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("Auto-dismissing offline banner")
            self.showOfflineBanner = false
        }
    }
    
    private func showReconnectionBannerToUser() {
        guard !showReconnectionBanner else {
            print("Reconnection banner already showing, skipping")
            return
        }
        
        guard hasBeenOfflineThisSession else {
            print("User was never offline this session, skipping reconnection banner")
            return
        }
        
        print("SHOWING RECONNECTION BANNER")
        showReconnectionBanner = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("Auto-dismissing reconnection banner")
            self.showReconnectionBanner = false
        }
    }
}
