import SwiftUI

@main
struct AniMenyuApp: App {
    @StateObject private var store = AniListStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(store)
        } label: {
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)

        Window("About AniMenyu", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}
