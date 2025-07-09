import SwiftUI

struct CalendarEventsView: View {
    @State private var isGoogleSynced = true
    @State private var autoPopulateAlarms = true
    @State private var showEvents = true

    let events = [
        ("Sat", "6", "Pick up @ Airport", "10:00 AM"),
        ("Mon", "8", "Party @ Ron's", "8:00 PM"),
        ("Mon", "8", "Drop off Tom", "10:00 PM")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Calendar")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)

                // Google sync toggle
                HStack {
                    Text("Sync Google Calendar")
                    Spacer()
                    Toggle("", isOn: $isGoogleSynced)
                        .labelsHidden()
                }
                .padding(.horizontal)

                // Apple calendar sync button
                Button(action: {
                    // Sync Apple Calendar logic
                }) {
                    Text("Sync Apple Calendar")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                // Upcoming Events
                DisclosureGroup("Upcoming Events", isExpanded: $showEvents) {
                    VStack(spacing: 10) {
                        ForEach(events, id: \.2) { (day, date, title, time) in
                            HStack {
                                VStack {
                                    Text(day)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(date)
                                        .font(.headline)
                                }
                                .frame(width: 40)

                                VStack(alignment: .leading) {
                                    Text(title)
                                        .fontWeight(.semibold)
                                    Text(time)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)

                // Auto-populate toggle
                HStack {
                    Text("Auto-populate Alarms")
                    Spacer()
                    Toggle("", isOn: $autoPopulateAlarms)
                        .labelsHidden()
                }
                .padding(.horizontal)

                // Sync Now button
                Button(action: {
                    // Sync action
                }) {
                    Text("Sync Now")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer()
            }
        }
    }
}
#Preview {
    CalendarEventsView()
}//
//  CalendarEventsView.swift
//  EZ Wake
//
//  Created by Prafulla Bhupathi Raju on 6/25/25.
//

