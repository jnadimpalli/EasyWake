    import SwiftUI

    struct UserSettingsView: View {
        @State private var homeStreet = ""
        @State private var homeCity = ""
        @State private var homeZip = ""
        @State private var homeState = "Select"
        
        @State private var workStreet = ""
        @State private var workCity = ""
        @State private var workZip = ""
        @State private var workState = "Select"

        @State private var clockFormat = "12hr"
        @State private var travelMethod = "Drive"
        
        let states = [
            "Select", "AK", "AL", "AR", "AZ", "CA", "CO", "CT", "DC", "DE", "FL", "GA", "HI", "IA",
          "ID", "IL", "IN", "KS", "KY", "LA", "MA", "MD", "ME", "MI", "MN", "MO", "MS",
          "MT", "NC", "ND", "NE", "NH", "NJ", "NM", "NV", "NY", "OH", "OK", "OR", "PA",
          "RI", "SC", "SD", "TN", "TX", "UT", "VA", "VT", "WA", "WI", "WV", "WY"
        ]
        let clockFormats = ["12hr", "24hr"]
        let travelOptions = ["Drive", "Public Transit/Metro", "Walk", "Bike"]

        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    Form {
                        Section(header: Text("Home Address")) {
                            TextField("Street Address", text: $homeStreet)
                            TextField("City", text: $homeCity)
                            
                            HStack {
                                TextField("Zipcode", text: $homeZip)
                                    .keyboardType(.numberPad)
                                
                                Spacer()
                                
                                Picker("State", selection: $homeState) {
                                    ForEach(states, id: \.self) { state in
                                        Text(state)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                            }
                        }

                        Section(header: Text("Work Address")) {
                            TextField("Street Address", text: $workStreet)
                            TextField("City", text: $workCity)
                            
                            HStack {
                                TextField("Zipcode", text: $workZip)
                                    .keyboardType(.numberPad)
                                
                                Spacer()
                                
                                Picker("State", selection: $workState) {
                                    ForEach(states, id: \.self) { state in
                                        Text(state)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                            }
                        }

                        Section(header: Text("Clock Format")) {
                            Picker("Clock Format", selection: $clockFormat) {
                                ForEach(clockFormats, id: \.self) {
                                    Text($0)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }

                        Section(header: Text("Travel Method")) {
                            Picker("Travel Method", selection: $travelMethod) {
                                ForEach(travelOptions, id: \.self) {
                                    Text($0)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }

                        Section {
                            NavigationLink(destination: CalendarSyncView()) {
                                Text("Calendar")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    VStack(spacing: 0) {
                        // Gradient (12px tall)
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0), Color.white]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 12)
                        .allowsHitTesting(false) // Let taps pass through

                        // Button with white background only behind it
                        ZStack {
                            Color.white // background only behind button
                            Button(action: {
                                print("Saved")
                            }) {
                                Text("Save and Continue")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                            }
                        }
                        .frame(height: 60) // match button + margin height
                        .padding(.bottom, 10)
                    }
                }
                .navigationTitle("User Settings")
            }
        }
    }

    #Preview {
        UserSettingsView()
    }//
    //  UserSettingsView.swift
    //  EZ Wake
    //
    //  Created by Prafulla Bhupathi Raju on 6/25/25.
    //

