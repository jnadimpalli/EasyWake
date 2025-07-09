// BottomNavBar.swift

import SwiftUI

struct BottomNavBar: View {
  @Binding var selection: MainContainerView.Tab
  private let tabs: [MainContainerView.Tab] = [.profile, .weather, .alarms, .calendar]

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      // ─── Indicator ──────────────────────────────
      GeometryReader { proxy in
        let count = CGFloat(tabs.count)
        let tabW  = proxy.size.width / count
        let idx   = CGFloat(tabs.firstIndex(of: selection) ?? 0)

        Capsule()
          .fill(Color.customBlue)
          .frame(width: tabW * 0.6, height: 3)
          .offset(
            x: idx * tabW + (tabW - tabW * 0.6)/2,
            y: -8
          )
          .animation(.easeInOut(duration: 0.25), value: selection)
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
      withAnimation { selection = tab }
    } label: {
      Image(systemName: iconName(for: tab))
        .font(.system(size: 28))
        .foregroundColor(selection == tab ? .customBlue : .primary)
        .frame(maxWidth: .infinity)
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
