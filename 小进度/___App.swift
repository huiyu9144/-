import SwiftUI

@main
struct 小进度App: App {
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("hasSetTheme") private var hasSetTheme = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(hasSetTheme ? (isDarkMode ? .dark : .light) : nil)
        }
    }
}
