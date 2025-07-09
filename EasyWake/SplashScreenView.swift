import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image("AppLogo") // Name in Assets.xcassets
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)

            Text("EZ Wake")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

#Preview {
    SplashScreenView()
}//
//  SplashScreenView.swift
//  EZ Wake
//
//  Created by Prafulla Bhupathi Raju on 6/24/25.
//

