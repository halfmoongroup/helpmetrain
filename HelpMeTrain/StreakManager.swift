import CoreData
import Foundation

@MainActor
final class StreakManager: ObservableObject {
    @Published private(set) var streakCount = 0

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = DataController.shared.container.viewContext) {
        self.context = context
    }

    func refresh(
        dailySteps: [Date: Int],
        goalSteps: Int,
        bonusState: BonusState
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastUpdated = calendar.startOfDay(for: bonusState.lastUpdated)
        let processStart = calendar.date(byAdding: .day, value: 1, to: lastUpdated) ?? today
        let startDate = min(processStart, today)
        let endDate = today

        var availableBonus = bonusState.currentBalanceValue
        var consecutiveAchieved = computeStreakEnding(on: calendar.date(byAdding: .day, value: -1, to: startDate) ?? startDate)

        for date in dates(from: startDate, to: endDate) {
            if date < startDate {
                continue
            }

            let steps = dailySteps[date] ?? 0
            let snapshot = fetchSnapshot(for: date) ?? DailySnapshot(context: context)
            let goal = snapshot.goalStepsValue > 0 ? snapshot.goalStepsValue : goalSteps
            let achieved = steps >= goal
            let isToday = date == today
            var usedBonus = false

            if achieved {
                consecutiveAchieved += 1
            } else if !isToday, availableBonus > 0 {
                availableBonus -= 1
                usedBonus = true
                consecutiveAchieved += 1
            } else {
                consecutiveAchieved = 0
            }

            if consecutiveAchieved > 0,
               bonusState.earnEveryNValue > 0,
               consecutiveAchieved % bonusState.earnEveryNValue == 0 {
                availableBonus = min(availableBonus + 1, bonusState.maxBalanceValue)
            }

            snapshot.date = date
            snapshot.goalSteps = Int32(goal)
            snapshot.actualSteps = Int32(steps)
            snapshot.usedBonus = usedBonus
        }

        streakCount = consecutiveAchieved
        bonusState.currentBalance = Int16(availableBonus)
        bonusState.lastUpdated = today
        saveContext()
    }

    private func fetchSnapshot(for date: Date) -> DailySnapshot? {
        let request = DailySnapshot.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "date == %@", date as NSDate)
        return try? context.fetch(request).first
    }

    private func computeStreakEnding(on date: Date) -> Int {
        let calendar = Calendar.current
        let snapshotMap = fetchSnapshotMap(endingAt: date)
        var streak = 0
        var current = date

        while let snapshot = snapshotMap[current] {
            if snapshot.actualStepsValue >= snapshot.goalStepsValue || snapshot.usedBonus {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else {
                    break
                }
                current = previous
            } else {
                break
            }
        }

        return streak
    }

    private func fetchSnapshotMap(endingAt date: Date) -> [Date: DailySnapshot] {
        let request = DailySnapshot.fetchRequest()
        request.predicate = NSPredicate(format: "date <= %@", date as NSDate)
        let snapshots = (try? context.fetch(request)) ?? []
        let calendar = Calendar.current
        return Dictionary(uniqueKeysWithValues: snapshots.map {
            (calendar.startOfDay(for: $0.date), $0)
        })
    }

    private func dates(from startDate: Date, to endDate: Date) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        var current = startDate
        while current <= endDate {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save streak data: \(error)")
        }
    }
}
