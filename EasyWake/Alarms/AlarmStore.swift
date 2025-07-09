// AlarmStore.swift

import Foundation
import Combine

class AlarmStore: ObservableObject {
  @Published var alarms: [Alarm] = []
  @Published var showingAddModal = false

  private let saveKey = "savedAlarms"

  init() { load() }

  func load() {
    guard
      let data = UserDefaults.standard.data(forKey: saveKey),
      let decoded = try? JSONDecoder().decode([Alarm].self, from: data)
    else { return }
    alarms = decoded
  }

  func save() {
    if let data = try? JSONEncoder().encode(alarms) {
      UserDefaults.standard.set(data, forKey: saveKey)
    }
  }

  func add(_ alarm: Alarm) {
    alarms.append(alarm)
    save()
  }

  func update(_ alarm: Alarm) {
    guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
    alarms[idx] = alarm
    save()
  }

  func delete(at offsets: IndexSet) {
    alarms.remove(atOffsets: offsets)
    save()
  }
}
