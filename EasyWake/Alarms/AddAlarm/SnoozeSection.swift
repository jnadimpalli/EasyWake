// SnoozeSection.swift

import SwiftUI

// MARK: - Snooze Section
struct SnoozeSection: View {
    @ObservedObject var viewModel: AddAlarmViewModel
    
    var body: some View {
        Section(header: Text("SNOOZE").textCase(.uppercase)) {
            // Main toggle
            Toggle("Enable Snooze", isOn: $viewModel.alarm.snoozeEnabled)
                .frame(minHeight: 44)
                .onChange(of: viewModel.alarm.snoozeEnabled) { _, isEnabled in
                    if isEnabled {
                        // Ensure defaults are set when enabling
                        if viewModel.alarm.maxSnoozes == 0 {
                            viewModel.alarm.maxSnoozes = 2
                        }
                        if viewModel.alarm.snoozeMinutes == 0 {
                            viewModel.alarm.snoozeMinutes = 9
                        }
                    }
                }
            
            // Additional settings when snooze is enabled
            if viewModel.alarm.snoozeEnabled {
                VStack(spacing: 0) {
                    // Max snoozes stepper
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Maximum Snoozes")
                                .font(.subheadline)
                            Text("Limit how many times you can snooze")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Stepper(
                            value: $viewModel.alarm.maxSnoozes,
                            in: 1...10,
                            step: 1
                        ) {
                            Text("\(viewModel.alarm.maxSnoozes)")
                                .font(.body)
                                .foregroundColor(.primary)
                                .monospacedDigit()
                                .frame(minWidth: 30, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Snooze duration stepper
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Snooze Duration")
                                .font(.subheadline)
                            Text("Time between snoozes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Stepper(
                            value: $viewModel.alarm.snoozeMinutes,
                            in: 1...30,
                            step: 1
                        ) {
                            Text("\(viewModel.alarm.snoozeMinutes) min")
                                .font(.body)
                                .foregroundColor(.primary)
                                .monospacedDigit()
                                .frame(minWidth: 60, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Total snooze time info
                    if viewModel.alarm.maxSnoozes > 0 && viewModel.alarm.snoozeMinutes > 0 {
                        let totalMinutes = viewModel.alarm.maxSnoozes * viewModel.alarm.snoozeMinutes
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Total snooze time: \(formatSnoozeTime(totalMinutes))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.alarm.snoozeEnabled)
            }
        }
    }
    
    private func formatSnoozeTime(_ totalMinutes: Int) -> String {
        if totalMinutes < 60 {
            return "\(totalMinutes) minutes"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes == 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            } else {
                return "\(hours) hr \(minutes) min"
            }
        }
    }
}
