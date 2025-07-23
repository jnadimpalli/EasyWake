//
//  PasswordInput.swift

import SwiftUI

/// A password field with an eye toggle inside the trailing edge.
struct RevealableSecureField: View {
    let title: String
    @Binding var text: String
    @State private var isSecure = true
    
    var body: some View {
        ZStack {
            if isSecure {
                SecureField(title, text: $text)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } else {
                TextField(title, text: $text)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .padding(.trailing, 44)                 // space for the eye
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .overlay(alignment: .trailing) {
            Button {
                isSecure.toggle()
            } label: {
                Image(systemName: isSecure ? "eye" : "eye.slash")
                    .foregroundColor(.gray)
                    .padding(.trailing, 14)
            }
        }
    }
}
