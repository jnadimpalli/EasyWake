import SwiftUI

struct AlarmSettingView: View {
    @State private var isVibrateOn = true
    @State private var selectedSound = "Tease"
    @State private var clockFormat = "AM"
    @State private var readyTime = ""
    @State private var adjustUsingMetrics = true

    let soundOptions = ["Tease", "Radial", "Shelter", "Quad", "Milky Way"]
    let clockOptions = ["AM", "PM"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Alarms")
                        .font(.title)
                        .bold()
                        .padding(.top)

                    Divider()

                    Toggle("Vibrate", isOn: $isVibrateOn)

                    VStack(alignment: .leading) {
                        Text("Alarm Sound")
                            .font(.headline)
                        Picker("Alarm Sound", selection: $selectedSound) {
                            ForEach(soundOptions, id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(height: 100)
                    }

                    VStack(alignment: .leading) {
                        Text("Clock Format")
                            .font(.headline)
                        Picker("Clock Format", selection: $clockFormat) {
                            ForEach(clockOptions, id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(maxWidth: 200)
                    }
                    .padding(10)

                    VStack(alignment: .leading) {
                        Text("Ready Time")
                            .font(.headline)
                        TextField("Enter time in minutes", text: $readyTime)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 200)
                    }

                    Toggle("Use metrics to adjust wake up time", isOn: $adjustUsingMetrics)

                    Spacer()
                }
                .padding()
            }
        }
    }
}

#Preview {
    AlarmSettingView()
}

//
//  AlarmSettingView.swift
//  EZ Wake
//
//  Created by Prafulla Bhupathi Raju on 6/26/25.
//

