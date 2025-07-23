import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image("WhiteLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)

            Text("Easy Wake")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.customBlue)
    }
}

#Preview {
    SplashScreenView()
}//
//  SplashScreenView.swift
//  Easy Wake
//
//  Created by Prafulla Bhupathi Raju on 6/24/25.
//

