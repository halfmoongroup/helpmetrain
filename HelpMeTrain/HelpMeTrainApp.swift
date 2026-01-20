import SwiftUI

@main
struct HelpMeTrainApp: App {
    @StateObject private var dataController = DataController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
        }
    }
}
