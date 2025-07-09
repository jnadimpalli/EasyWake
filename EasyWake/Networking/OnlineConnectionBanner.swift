import SwiftUI

struct OnlineConnectionBanner: View {
    @State private var progress: Double = 0.0
    @State private var isVisible = true
    
    var body: some View {
        HStack(spacing: 8) {
            // Warning icon
            Image(systemName: "network")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0/255, green: 187/255, blue: 249/255))
            
            // Banner text
            Text("Back online")
                .font(.system(.body, design: .default, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 40)
        .background(
            ZStack {
                // White background
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                
                // Green Animated border
                RoundedRectangle(cornerRadius: 20)
                    .trim(from: 0, to: progress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .animation(.linear(duration: 5.0), value: progress)
            }
        )
        .padding(.horizontal, 16)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            // Start progress animation immediately
            withAnimation(.linear(duration: 5.0)) {
                progress = 1.0
            }
            
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation(.easeIn(duration: 0.3)) {
                    isVisible = false
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Back online. Weather and traffic data now available.")
    }
}
