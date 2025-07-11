// RootView.swift

import SwiftUI

struct RootView: View {
  @State private var showSplash = true
  @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false

  var body: some View {
    Group {
      if showSplash {
        SplashScreenView()
      } else if !didCompleteOnboarding {
        GetStartedView()
      } else {
        MainContainerView()
      }
    }
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
        withAnimation { showSplash = false }
      }
    }
  }
}

#Preview {
    RootView()
}
