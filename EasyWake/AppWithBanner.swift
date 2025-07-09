import SwiftUI

struct AppWithBanner<Content: View>: View {
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var bannerManager = OfflineBannerManager()
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        print("AppWithBanner: Initializing")
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                content
                
                // Offline Banner
                if bannerManager.showOfflineBanner {
                    VStack {
                        OfflineConnectionBanner()
                            .padding(.top, geo.safeAreaInsets.top + 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .zIndex(999)
                    .animation(.easeInOut(duration: 0.3), value: bannerManager.showOfflineBanner)
                }
                
                // Reconnection Banner
                if bannerManager.showReconnectionBanner {
                    VStack {
                        OnlineConnectionBanner()
                            .padding(.top, geo.safeAreaInsets.top + 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .zIndex(999)
                    .animation(.easeInOut(duration: 0.3), value: bannerManager.showReconnectionBanner)
                }
            }
        }
        .onChange(of: networkMonitor.isConnected) { oldValue, newValue in
            print("AppWithBanner: Network state changed from \(oldValue) to \(newValue)")
            bannerManager.handleNetworkChange(isConnected: newValue)
        }
        .onAppear {
            print("AppWithBanner: onAppear - initial connection state: \(networkMonitor.isConnected)")
            bannerManager.handleNetworkChange(isConnected: networkMonitor.isConnected)
        }
    }
}
