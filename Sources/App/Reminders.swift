import Foundation
import UserNotifications

@MainActor enum ReminderScheduler {
    static func reconcile(cards: [Card], requestPermission: Bool) async throws -> String {
        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings()
        if requestPermission && settings.authorizationStatus == .notDetermined {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
            settings = await center.notificationSettings()
        }
        let prefix = "finance."
        let pending = await center.pendingNotificationRequests()
        let previous = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            center.removePendingNotificationRequests(withIdentifiers: previous)
            return settings.authorizationStatus == .denied ? "Desactivados en iOS" : "No solicitado"
        }
        struct Planned {
            var id: String
            var date: Date
            var cut: Bool
        }
        var plan: [Planned] = []
        for card in cards where card.credit && card.reminders {
            for offset in 0..<12 {
                for (day, cut) in [(card.cutDay, true), (card.payDay, false)] {
                    let event = FinanceDates.monthDate(anchor: .now, offset: offset, day: day)
                    for advance in [7, 3] {
                        let day = FinanceDates.addDays(-advance, to: event)
                        guard let date = FinanceDates.calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day), date > .now else { continue }
                        let id = prefix + card.id.uuidString + ".\(cut).\(Int(event.timeIntervalSince1970)).\(advance)"
                        plan.append(Planned(id: id, date: date, cut: cut))
                    }
                }
            }
        }
        // Keep a bounded rolling horizon; refresh on launch/foreground/config changes.
        let selected = Array(plan.sorted { $0.date < $1.date }.prefix(60))
        let keep = Set(selected.map(\.id))
        center.removePendingNotificationRequests(withIdentifiers: previous.filter { !keep.contains($0) })
        for item in selected {
            let content = UNMutableNotificationContent()
            content.title = "Recordatorio financiero"
            content.body = item.cut ? "Se aproxima una fecha de corte. Revisa tus registros en la app." : "Se aproxima una fecha de pago. Revisa tus registros en la app."
            content.sound = .default
            var components = FinanceDates.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            components.timeZone = FinanceDates.calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
        return "\(selected.count) avisos programados · 9:00, hora de Ciudad de México. Se renuevan al abrir la app."
    }
}
