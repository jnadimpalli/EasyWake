import Foundation
import Network
import Combine

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var debounceTimer: Timer?
    private var pendingConnectedState: Bool?
    
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let interfaceType = path.availableInterfaces.first?.type
            
            DispatchQueue.main.async {
                self?.connectionType = interfaceType
                
                if !connected {
                    // Immediate disconnection detection
                    self?.updateConnectionState(false)
                } else {
                    // For connections, debounce and verify
                    self?.debounceConnectionChange(true)
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func debounceConnectionChange(_ connected: Bool) {
        // Cancel any pending timer
        debounceTimer?.invalidate()
        
        // Store the pending state
        pendingConnectedState = connected
        
        // Wait 2 seconds before applying the change
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self, let pendingState = self.pendingConnectedState else { return }
            
            if pendingState {
                // For connection, verify internet access
                self.verifyConnectivityAndUpdate()
            } else {
                // For disconnection, apply immediately
                self.updateConnectionState(false)
            }
        }
    }
    
    private func verifyConnectivityAndUpdate() {
        guard let url = URL(string: "https://www.apple.com") else {
            updateConnectionState(false)
            return
        }
        
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0 // 5 second timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                let isReachable = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
                self?.updateConnectionState(isReachable)
            }
        }
        task.resume()
    }
    
    private func updateConnectionState(_ connected: Bool) {
        guard isConnected != connected else {
            return
        }
        
        isConnected = connected
        pendingConnectedState = nil
    }
    
    deinit {
        debounceTimer?.invalidate()
        monitor.cancel()
    }
}
