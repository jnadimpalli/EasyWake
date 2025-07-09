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
        print("NetworkMonitor: Initializing")
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let interfaceType = path.availableInterfaces.first?.type
            
            print("NetworkMonitor: Raw path update - status: \(path.status), satisfied: \(connected)")
            print("NetworkMonitor: Available interfaces: \(path.availableInterfaces)")
            
            DispatchQueue.main.async {
                self?.connectionType = interfaceType
                
                if !connected {
                    // Immediate disconnection detection
                    print("NetworkMonitor: Immediate disconnection detected")
                    self?.updateConnectionState(false)
                } else {
                    // For connections, debounce and verify
                    print("NetworkMonitor: Connection detected, will verify with debounce")
                    self?.debounceConnectionChange(true)
                }
            }
        }
        monitor.start(queue: queue)
        print("NetworkMonitor: Started monitoring")
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
        
        print("NetworkMonitor: Verifying internet connectivity")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0 // 5 second timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                let isReachable = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
                print("NetworkMonitor: Connectivity verification result: \(isReachable)")
                self?.updateConnectionState(isReachable)
            }
        }
        task.resume()
    }
    
    private func updateConnectionState(_ connected: Bool) {
        guard isConnected != connected else {
            print("NetworkMonitor: State unchanged, skipping update")
            return
        }
        
        print("NetworkMonitor: Updating connection state to: \(connected)")
        isConnected = connected
        pendingConnectedState = nil
    }
    
    deinit {
        print("NetworkMonitor: Deinitializing")
        debounceTimer?.invalidate()
        monitor.cancel()
    }
}
