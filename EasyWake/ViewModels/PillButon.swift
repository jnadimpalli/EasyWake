//  PillButon.swift

import SwiftUI

struct PillButtonStyle: ButtonStyle {
    var fill: Color
    var textColor: Color = .white
    var border: Color? = nil
    var height: CGFloat = 48
    var horizontalPadding: CGFloat = 24

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(textColor)
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .background(
                Capsule()
                    .fill(fill.opacity(configuration.isPressed ? 0.7 : 1.0))
            )
            .overlay(
                Capsule()
                    .stroke(border ?? .clear, lineWidth: border == nil ? 0 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

// Handy sugar
extension View {
    func pillButton(
        fill: Color,
        textColor: Color = .white,
        border: Color? = nil,
        height: CGFloat = 48,
        hPadding: CGFloat = 24
    ) -> some View {
        buttonStyle(
            PillButtonStyle(
                fill: fill,
                textColor: textColor,
                border: border,
                height: height,
                horizontalPadding: hPadding
            )
        )
    }
}

enum SocialType { case google, apple }

struct SocialButton: View {
    let type: SocialType
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if type == .google {
                    Image("GoogleIcon")
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "applelogo")
                        .font(.system(size: 20, weight: .bold))
                }
                Text(title)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(type == .google ? Color.white : Color.black)
            .foregroundColor(type == .google ? .black : .white)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(borderColor, lineWidth: borderWidth)
            )
        }
    }

    private var borderWidth: CGFloat {
        (type == .apple && scheme == .dark) ? 1 : (type == .google ? 1 : 0)
    }

    private var borderColor: Color {
        if type == .apple && scheme == .dark { return .white.opacity(0.7) }
        if type == .google { return .black.opacity(0.6) }
        return .clear
    }
}

// MARK: - "OR" divider with lines
struct OrDivider: View {
    var body: some View {
        HStack {
            Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
            Text("Or")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
        }
        .padding(.vertical, 8)
    }
}
