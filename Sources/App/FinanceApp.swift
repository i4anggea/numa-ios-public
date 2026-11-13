import SwiftUI

@main struct FinanceApp: App {
    @State private var store = FinanceStore.shared
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "es_MX"))
                .environment(\.calendar, FinanceDates.calendar)
                .environment(\.timeZone, FinanceDates.calendar.timeZone)
        }
    }
}
