import SwiftUI
import EventKit
// COMMENTED OUT: Google imports
// import GoogleSignIn
// import GoogleAPIClientForREST

/// Presentation model for either Google or Apple events
private struct DisplayEvent: Identifiable, Hashable {
    let id         = UUID()
    let title      : String
    let date       : String    // e.g. "Thu 3"
    let time       : String    // e.g. "11:00 AM"
    let dateObject : Date      // real Date for sorting
}

struct CalendarSyncView: View {
    // MARK: – persisted between launches
    // COMMENTED OUT: Google sync state
    // @AppStorage("isGoogleSynced") private var isGoogleSynced = false
    @AppStorage("isAppleSynced")  private var isAppleSynced  = false
    @AppStorage("autoPopulate")   private var autoPopulate   = false

    // MARK: – runtime toggles & state
    // COMMENTED OUT: Google toggle
    // @State private var googleEnabled = true
    @State private var appleEnabled  = true
    @State private var isLoading     = false

    // MARK: – our in-memory lists
    // COMMENTED OUT: Google events
    // @State private var googleEvents: [DisplayEvent] = []
    @State private var appleEvents:  [DisplayEvent] = []

    // MARK: – shared AlarmStore for auto-populate
    @StateObject private var alarmStore = AlarmStore()

    // MARK: – Google API client - COMMENTED OUT
    // @State private var apiService = GTLRCalendarService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                // MARK: Top Bar (matching Alarms format)
                VStack(spacing: 0) {
                    HStack {
                        Text("Calendar")
                            .font(.title2).bold()
                        Spacer()
                    }
                    .padding(.horizontal)
                    Divider()
                }

                // 1) Calendar on/off toggles (vertical) - UPDATED: Only Apple
                if isAppleSynced {
                    VStack(alignment: .leading, spacing: 8) {
                        // COMMENTED OUT: Google toggle
                        // if isGoogleSynced {
                        //     Toggle("Google Calendar", isOn: $googleEnabled)
                        // }
                        if isAppleSynced {
                            Toggle("Apple Calendar", isOn: $appleEnabled)
                        }
                    }
                    .padding(.horizontal)
                }

                // 2) Sync buttons (only if not yet authorized) - UPDATED: Only Apple
                VStack(spacing: 12) {
                    // COMMENTED OUT: Google sync button
                    // if !isGoogleSynced {
                    //     GoogleSyncButton { signInWithGoogle() }
                    // }
                    if !isAppleSynced {
                        AppleSyncButton { requestAppleAccess() }
                    }
                }
                .padding(.horizontal)

                // 3) Upcoming Events + pull-to-refresh + spinner - UPDATED: Only Apple
                if isAppleSynced {
                    Text("Upcoming Events")
                        .font(.headline)
                        .padding(.horizontal)

                    ZStack {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(filteredDisplayEvents()) { evt in
                                    EventRowView(title: evt.title,
                                                 date:  evt.date,
                                                 time:  evt.time)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: UIScreen.main.bounds.height * 0.33)
                        .refreshable {
                            await refreshAllCalendars()
                        }

                        if isLoading {
                            Color(.systemBackground)
                                .opacity(0.6)
                                .ignoresSafeArea()
                            ProgressView("Refreshing…")
                                .progressViewStyle(.circular)
                        }
                    }
                }

                // 4) Auto-populate Alarms (persisted)
                Toggle("Auto-populate Alarms", isOn: $autoPopulate)
                    .padding(.horizontal)
//                    .onChange(of: autoPopulate) { on in
//                        if on { createAlarmsFromEvents() }
//                    }

                Spacer()
            }
            .onAppear {
                // UPDATED: Only Apple calendar on appear
                // COMMENTED OUT: Google restore
                // if isGoogleSynced {
                //     Task {
                //       if (try? await GIDSignIn.sharedInstance.restorePreviousSignIn()) != nil {
                //         fetchGoogleEvents()
                //       } else {
                //         // session expired or revoked – force them to re-sync
                //         isGoogleSynced = false
                //       }
                //     }
                //   }
                if isAppleSynced  { requestAppleAccess() }
            }
        }
    }
    
    // COMMENTED OUT: Google restore function
    // /// Call this once in .onAppear to pick up any prior Google session:
    // private func restoreGoogleSignInIfNeeded() {
    //   Task {
    //     do {
    //       // this will throw if there was no prior sign-in
    //       let _ = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
    //       // if we got here, there *is* a currentUser
    //       isGoogleSynced = true
    //       await fetchGoogleEvents()
    //     } catch {
    //       // no prior sign-in (or it failed), so we stay signed-out
    //       print("No previous Google sign-in:", error)
    //     }
    //   }
    // }

    // MARK: – merge + sort newest-first - UPDATED: Only Apple events
    private func filteredDisplayEvents() -> [DisplayEvent] {
        var all = [DisplayEvent]()
        // COMMENTED OUT: Google events
        // if isGoogleSynced && googleEnabled {
        //     all += googleEvents
        // }
        if isAppleSynced && appleEnabled {
            all += appleEvents
        }
        return all.sorted { $0.dateObject < $1.dateObject }
    }

    // MARK: – pull-to-refresh helper - UPDATED: Only Apple
    private func refreshAllCalendars() async {
        isLoading = true
        defer { isLoading = false }

        // COMMENTED OUT: Google refresh
        // if isGoogleSynced {
        //     await withCheckedContinuation { cont in
        //         fetchGoogleEvents { cont.resume() }
        //     }
        // }
        if isAppleSynced {
            await withCheckedContinuation { cont in
                requestAppleAccess(completion: cont.resume)
            }
        }
    }

    // MARK: – auto-populate your AlarmStore
//    private func createAlarmsFromEvents() {
//      // 1) Remove any alarms we auto-populated last time,
//      //    but leave the rest of the user's alarms untouched.
//      alarmStore.alarms.removeAll { $0.isAutoPopulated }
//
//      // 2) For each upcoming event, create exactly one new alarm
//      for evt in filteredDisplayEvents() {
//        var alarm = Alarm()
//        alarm.name             = evt.title
//        alarm.schedule         = .specificDate(evt.dateObject)
//        alarm.time             = evt.dateObject
//        alarm.arrivalTime      = evt.dateObject
//        alarm.isAutoPopulated  = true
//        alarmStore.add(alarm)
//      }
//    }

    // COMMENTED OUT: All Google Sign-In functionality
    // // MARK: – Google Sign-in + attach both OAuth & API key
    // private func signInWithGoogle() {
    //   // 1) Read your reversed OAuth client-ID from Info.plist
    //   guard let clientID = Bundle.main
    //     .object(forInfoDictionaryKey: "CLIENT_ID") as? String
    //   else {
    //     print("Missing CLIENT_ID in Info.plist")
    //     return
    //   }

    //   // 2) Install that into the singleton up front
    //   GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

    //   // 3) Find a UIViewController to present from
    //   guard
    //     let windowScene = UIApplication.shared.connectedScenes
    //                          .first(where: { $0.activationState == .foregroundActive })
    //                          as? UIWindowScene,
    //     let rootVC = windowScene.windows.first?.rootViewController
    //   else {
    //     print("Could not find a root view controller")
    //     return
    //   }

    //   // 4) Perform the async/await sign-in
    //   Task {
    //     do {
    //       // NOTE: we no longer pass the config in here
    //       //      the singleton already has it
    //       let signInResult = try await GIDSignIn.sharedInstance.signIn(
    //         withPresenting: rootVC
    //       )

    //       // 5) Mark ourselves "signed in"
    //       isGoogleSynced = true

    //       // 6) Wire the returned GIDGoogleUser into your Calendar service
    //       //    in v7 the user comes back inside a SignInResult:
    //       let user = signInResult.user
    //       apiService.authorizer = user.fetcherAuthorizer

    //       // 7) Fire off your first fetch
    //       fetchGoogleEvents()

    //     } catch {
    //       print("Google sign-in failed:", error)
    //     }
    //   }
    // }

    // COMMENTED OUT: Google events fetching
    // private func fetchGoogleEvents(completion: @escaping () -> Void = {}) {
    //   // 1) Grab your unrestricted API key
    //   guard let apiKey = Bundle.main
    //           .object(forInfoDictionaryKey: "GOOGLE_API_KEY") as? String else {
    //     print("❌ Missing GOOGLE_API_KEY in Info.plist")
    //     completion()
    //     return
    //   }

    //   // 2) Get the signed-in user
    //   guard let user = GIDSignIn.sharedInstance.currentUser else {
    //     print("❌ No signed-in Google user")
    //     completion()
    //     return
    //   }
    //   let tokenString = user.accessToken.tokenString

    //   // 3) Build the URL with your API key + time window
    //   var comps = URLComponents(string:
    //     "https://www.googleapis.com/calendar/v3/calendars/primary/events"
    //   )!
    //   let now     = Date()
    //   let oneWeek = Calendar.current.date(
    //     byAdding: .weekOfYear, value: 1, to: now
    //   )!
    //   let iso = ISO8601DateFormatter()
    //   iso.formatOptions = [.withInternetDateTime]
    //   comps.queryItems = [
    //     .init(name: "key",          value: apiKey),
    //     .init(name: "timeMin",      value: iso.string(from: now)),
    //     .init(name: "timeMax",      value: iso.string(from: oneWeek)),
    //     .init(name: "singleEvents", value: "true"),
    //     .init(name: "orderBy",      value: "startTime")
    //   ]

    //   // 4) Make the request
    //   var req = URLRequest(url: comps.url!)
    //   req.setValue("Bearer \(tokenString)", forHTTPHeaderField: "Authorization")

    //   URLSession.shared.dataTask(with: req) { data, _, error in
    //     defer { completion() }

    //     if let error = error {
    //       print("❌ Network error fetching calendar:", error)
    //       return
    //     }
    //     guard let data = data else {
    //       print("❌ No data from Google Calendar API")
    //       return
    //     }

    //     // 5) Decode JSON, allowing for either `dateTime` or `date`
    //     struct APIResponse: Codable {
    //       struct Item: Codable {
    //         let summary: String?
    //         let start:   StartInfo
    //       }
    //       struct StartInfo: Codable {
    //         let dateTime: Date?
    //         let date:     String?

    //         // custom decoder so `dateTime` uses ISO8601 and `date` is left as string
    //         init(from decoder: Decoder) throws {
    //           let c = try decoder.container(keyedBy: CodingKeys.self)
    //           if let dtString = try? c.decode(String.self, forKey: .dateTime) {
    //             // parse ISO8601
    //             let iso = ISO8601DateFormatter()
    //             dateTime = iso.date(from: dtString)
    //           } else {
    //             dateTime = nil
    //           }
    //           date = try? c.decode(String.self, forKey: .date)
    //         }
    //         private enum CodingKeys: String, CodingKey {
    //           case dateTime, date
    //         }
    //       }
    //       let items: [Item]?
    //     }

    //     do {
    //       // use the default decoder (dates already handled in StartInfo)
    //       let resp = try JSONDecoder().decode(APIResponse.self, from: data)
    //       let raw = resp.items ?? []

    //       // formatters for display
    //       let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
    //       let ds = DateFormatter(); ds.dateFormat = "E d"
    //       let isoDay = ISO8601DateFormatter() // for parsing all-day date strings

    //       // 6) Map to DisplayEvent, picking whichever date we got
    //       let evts = raw.compactMap { item -> DisplayEvent? in
    //         // determine actual Date value:
    //         let dt: Date
    //         if let d = item.start.dateTime {
    //           dt = d
    //         } else if let day = item.start.date,
    //                   let parsed = isoDay.date(from: day) {
    //           // Skip all-day events (they only have a 'date' field, not 'dateTime')
    //           return nil
    //         } else {
    //           return nil
    //         }

    //         let timePart = df.string(from: dt).split(separator: " ")
    //                            .last.map(String.init) ?? ""
    //         return DisplayEvent(
    //           title:      item.summary ?? "(No title)",
    //           date:       ds.string(from: dt),
    //           time:       timePart,
    //           dateObject: dt
    //         )
    //       }
    //       .sorted(by: { $0.dateObject > $1.dateObject }) // newest first

    //       DispatchQueue.main.async {
    //         self.googleEvents = evts
    //       }

    //     } catch {
    //       print("❌ JSON decode error:", error)
    //     }
    //   }.resume()
    // }

    // MARK: – Apple EventKit
    private func requestAppleAccess(completion: @escaping ()->Void = {}) {
        let store = EKEventStore()

        // our shared handler matches both signatures
        let handler: (Bool, Error?) -> Void = { granted, _ in
            guard granted else { completion(); return }
            let start = Date()
            let end   = Calendar.current.date(
                byAdding: .weekOfYear, value: 1, to: start
            )!
            let pred = store.predicateForEvents(
                withStart: start, end: end, calendars: nil
            )
            let raw  = store.events(matching: pred)

            DispatchQueue.main.async {
                let ds = DateFormatter(); ds.dateFormat = "E d"
                let tf = DateFormatter(); tf.dateFormat = "h:mm a"
                self.appleEvents = raw.compactMap { event in
                    // Skip all-day events
                    if event.isAllDay {
                        return nil
                    }
                    return DisplayEvent(
                        title:      event.title,
                        date:       ds.string(from: event.startDate),
                        time:       tf.string(from: event.startDate),
                        dateObject: event.startDate
                    )
                }
                self.isAppleSynced = true
                completion()
            }
        }

        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents(completion: handler)
        } else {
            store.requestAccess(to: .event) { granted, error in
                handler(granted, error)
            }
        }
    }
}

// MARK: – Buttons & Row

// COMMENTED OUT: Google sync button
// private struct GoogleSyncButton: View {
//     let action: ()->Void
//     var body: some View {
//         Button(action: action) {
//             HStack(spacing: 12) {
//                 Image("GoogleIcon")
//                   .resizable().renderingMode(.original)
//                   .scaledToFit().frame(width:20,height:20)
//                 Text("Sync Google Calendar")
//                   .fontWeight(.semibold)
//             }
//             .frame(maxWidth:.infinity)
//             .padding()
//             .background(Color.white)
//             .cornerRadius(8)
//             .overlay(RoundedRectangle(cornerRadius:8).stroke(Color.black))
//         }
//     }
// }

private struct AppleSyncButton: View {
    let action: ()->Void
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "applelogo")
                Text("Sync Apple Calendar").fontWeight(.semibold)
            }
            .frame(maxWidth:.infinity)
            .padding()
            .background(Color.black).foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}

private struct EventRowView: View {
    let title, date, time: String
    var body: some View {
        HStack {
            VStack(alignment:.leading,spacing:4) {
                Text(date).font(.subheadline).foregroundColor(.gray)
                Text(title).font(.headline)
            }
            Spacer()
            Text(time).font(.subheadline)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
  CalendarSyncView()
}
