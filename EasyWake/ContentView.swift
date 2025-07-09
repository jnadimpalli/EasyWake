//
//  ContentView.swift
//  Easy Wake
//
//  Created by Prafulla Bhupathi Raju on 6/24/25.
//
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    SplashScreenView()
}
