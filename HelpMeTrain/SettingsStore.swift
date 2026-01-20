import CoreData
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var dailyStepTarget: Int {
        didSet { settings.dailyStepTarget = Int32(dailyStepTarget); save() }
    }
    @Published var recentHRWindowMinutes: Int {
        didSet { settings.recentHRWindowMinutes = Int16(recentHRWindowMinutes); save() }
    }
    @Published var bonusEarnEveryN: Int {
        didSet { bonusState.earnEveryN = Int16(bonusEarnEveryN); save() }
    }
    @Published var maxBonusDays: Int {
        didSet { bonusState.maxBalance = Int16(maxBonusDays); save() }
    }
    @Published var currentBonusDays: Int {
        didSet { bonusState.currentBalance = Int16(currentBonusDays); save() }
    }

    private let context: NSManagedObjectContext
    private let settings: Settings
    private let bonusState: BonusState

    init(context: NSManagedObjectContext = DataController.shared.container.viewContext) {
        self.context = context

        if let existing = SettingsStore.fetchSettings(context: context) {
            settings = existing
        } else {
            settings = Settings(context: context)
            settings.dailyStepTarget = 10_000
            settings.recentHRWindowMinutes = 10
        }

        if let existingBonus = SettingsStore.fetchBonusState(context: context) {
            bonusState = existingBonus
        } else {
            bonusState = BonusState(context: context)
            bonusState.currentBalance = 0
            bonusState.maxBalance = 3
            bonusState.earnEveryN = 7
            bonusState.lastUpdated = Date()
        }

        dailyStepTarget = Int(settings.dailyStepTarget)
        recentHRWindowMinutes = Int(settings.recentHRWindowMinutes)
        bonusEarnEveryN = Int(bonusState.earnEveryN)
        maxBonusDays = Int(bonusState.maxBalance)
        currentBonusDays = Int(bonusState.currentBalance)

        save()
    }

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save settings: \(error)")
        }
    }

    private static func fetchSettings(context: NSManagedObjectContext) -> Settings? {
        let request = Settings.fetchRequest()
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    static func fetchBonusState(context: NSManagedObjectContext) -> BonusState? {
        let request = BonusState.fetchRequest()
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    func updateBonusBalance(_ newValue: Int) {
        let clamped = max(0, min(newValue, maxBonusDays))
        if clamped != currentBonusDays {
            currentBonusDays = clamped
        }
    }

    func bonusStateObject() -> BonusState {
        bonusState
    }
}
