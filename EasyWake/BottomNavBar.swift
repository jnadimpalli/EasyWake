// BottomNavBar.swift

import SwiftUI

struct BottomNavBar: View {
    @Binding var selection: MainContainerView.Tab
    private let tabs: [MainContainerView.Tab] = [.profile, .weather, .alarms, .calendar]
    
    // State for overshoot animation
    @State private var overshootOffset: CGFloat = 0
    @State private var isAnimating = false
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // ─── Indicator ──────────────────────────────
            GeometryReader { proxy in
                let count = CGFloat(tabs.count)
                let tabW  = proxy.size.width / count
                let idx   = CGFloat(tabs.firstIndex(of: selection) ?? 0)
                let baseOffset = idx * tabW + (tabW - tabW * 0.6)/2
                
                Capsule()
                    .fill(Color.customBlue)
                    .frame(width: tabW * 0.6, height: 3)
                    .offset(
                        x: baseOffset + overshootOffset,
                        y: -8
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0), value: selection)
                    .animation(.spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0), value: overshootOffset)
            }
            .allowsHitTesting(false)
            
            // ─── Buttons ─────────────────────────────────
            HStack {
                ForEach(tabs, id: \.self) { tab in
                    navButton(for: tab)
                }
            }
            .padding(.horizontal, 12)
        }
        // ─── KEEP YOUR ORIGINAL HEIGHT ────────────────
        .frame(height: 44)
        .padding(.top, 12)
        .padding(.bottom, 40)
        
        // ─── LIGHT TRANSLUCENT BACKGROUND ────────────
        .background(Color(.secondarySystemBackground).opacity(0.95))
        
        // ─── ONLY A TOP BORDER ───────────────────────
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.5)),
            alignment: .top
        )
        
        // ─── underlap just the very bottom safe area ──
        .ignoresSafeArea(edges: .bottom)
    }
    
    @ViewBuilder
    private func navButton(for tab: MainContainerView.Tab) -> some View {
        Button {
            animateWithOvershoot(to: tab)
        } label: {
            Image(systemName: iconName(for: tab))
                .font(.system(size: 28))
                .foregroundColor(selection == tab ? .customBlue : .primary)
                .frame(maxWidth: .infinity)
                .scaleEffect(selection == tab && isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isAnimating)
        }
    }
    
    private func animateWithOvershoot(to tab: MainContainerView.Tab) {
        guard tab != selection else { return }
        
        let currentIndex = tabs.firstIndex(of: selection) ?? 0
        let targetIndex = tabs.firstIndex(of: tab) ?? 0
        let direction: CGFloat = targetIndex > currentIndex ? 1 : -1
        
        // Calculate overshoot amount based on distance
        let distance = abs(targetIndex - currentIndex)
        let overshootAmount: CGFloat = 20 * CGFloat(distance) * direction
        
        // Start animation sequence
        isAnimating = true
        
        // Phase 1: Start moving and apply overshoot
        withAnimation(.easeOut(duration: 0.15)) {
            selection = tab
            overshootOffset = overshootAmount
        }
        
        // Phase 2: Spring back to position
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                overshootOffset = 0
                isAnimating = false
            }
        }
    }
    
    private func iconName(for tab: MainContainerView.Tab) -> String {
        switch tab {
        case .profile:  return "person.circle"
        case .weather:  return "cloud.sun"
        case .alarms:   return "alarm"
        case .calendar: return "calendar"
        }
    }
}
