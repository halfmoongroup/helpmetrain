//
//  HelpMeTrainTests.swift
//  HelpMeTrainTests
//
//  Created by Tony Giaccone on 1/18/26.
//

import CoreData
import Testing
@testable import HelpMeTrain

struct HelpMeTrainTests {

    @Test func streakCountsWithoutBonus() async throws {
        let context = makeInMemoryContext()
        let streakManager = StreakManager(context: context)
        let bonus = makeBonusState(context: context, current: 0, earnEveryN: 7, max: 3)

        let dailySteps = [5000, 9000, 10000, 12000, 10000, 4000, 11000]
        let stepsMap = makeDailyStepsMap(steps: dailySteps)
        bonus.lastUpdated = dayBefore(startDate(for: dailySteps))
        streakManager.refresh(dailySteps: stepsMap, goalSteps: 10000, bonusState: bonus)

        #expect(streakManager.streakCount == 1)
        #expect(bonus.currentBalance == 0)
    }

    @Test func streakConsumesBonusToPreserve() async throws {
        let context = makeInMemoryContext()
        let streakManager = StreakManager(context: context)
        let bonus = makeBonusState(context: context, current: 1, earnEveryN: 7, max: 3)

        let dailySteps = [10000, 9000, 10000, 10000, 10000, 10000, 8000]
        let stepsMap = makeDailyStepsMap(steps: dailySteps)
        bonus.lastUpdated = dayBefore(startDate(for: dailySteps))
        streakManager.refresh(dailySteps: stepsMap, goalSteps: 10000, bonusState: bonus)

        #expect(streakManager.streakCount == 7)
        #expect(bonus.currentBalance == 0)
    }

    @Test func bonusEarnedAfterConsecutiveDays() async throws {
        let context = makeInMemoryContext()
        let streakManager = StreakManager(context: context)
        let bonus = makeBonusState(context: context, current: 0, earnEveryN: 3, max: 2)

        let dailySteps = [11000, 12000, 10000, 9000, 10000, 10000, 10000]
        let stepsMap = makeDailyStepsMap(steps: dailySteps)
        bonus.lastUpdated = dayBefore(startDate(for: dailySteps))
        streakManager.refresh(dailySteps: stepsMap, goalSteps: 10000, bonusState: bonus)

        #expect(streakManager.streakCount == 3)
        #expect(bonus.currentBalance == 2)
    }

    @Test func snapshotsUseStartOfDayBoundary() async throws {
        let context = makeInMemoryContext()
        let streakManager = StreakManager(context: context)
        let bonus = makeBonusState(context: context, current: 0, earnEveryN: 7, max: 3)

        let dailySteps = [12000, 12000, 12000, 12000, 12000, 12000, 12000]
        let stepsMap = makeDailyStepsMap(steps: dailySteps)
        bonus.lastUpdated = dayBefore(startDate(for: dailySteps))
        streakManager.refresh(dailySteps: stepsMap, goalSteps: 10000, bonusState: bonus)

        let snapshots = fetchSnapshots(context: context)
        let calendar = Calendar.current
        #expect(snapshots.count == 7)
        for snapshot in snapshots {
            let startOfDay = calendar.startOfDay(for: snapshot.date)
            #expect(snapshot.date == startOfDay)
        }
    }

    @Test func goalSnapshotPersistsAcrossGoalChanges() async throws {
        let context = makeInMemoryContext()
        let streakManager = StreakManager(context: context)
        let bonus = makeBonusState(context: context, current: 0, earnEveryN: 7, max: 3)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.date(byAdding: .day, value: -3, to: today) ?? today
        let snapshot = DailySnapshot(context: context)
        snapshot.date = targetDate
        snapshot.goalSteps = 12000
        snapshot.actualSteps = 8000
        snapshot.usedBonus = false

        let dailySteps = [8000, 8000, 8000, 8000, 8000, 8000, 8000]
        let stepsMap = makeDailyStepsMap(steps: dailySteps)
        bonus.lastUpdated = dayBefore(startDate(for: dailySteps))
        streakManager.refresh(dailySteps: stepsMap, goalSteps: 8000, bonusState: bonus)

        let stored = fetchSnapshot(context: context, date: targetDate)
        #expect(stored?.goalStepsValue == 12000)
    }

    @Test func bonusDayOnBoundaryPreservesStreak() async throws {
        let context = makeInMemoryContext()
        let streakManager = StreakManager(context: context)
        let bonus = makeBonusState(context: context, current: 1, earnEveryN: 7, max: 3)

        let dailySteps = [10000, 10000, 10000, 10000, 10000, 0, 10000]
        let stepsMap = makeDailyStepsMap(steps: dailySteps)
        bonus.lastUpdated = dayBefore(startDate(for: dailySteps))
        streakManager.refresh(dailySteps: stepsMap, goalSteps: 10000, bonusState: bonus)

        #expect(streakManager.streakCount == 7)
        #expect(bonus.currentBalance == 0)
    }
}

private func makeInMemoryContext() -> NSManagedObjectContext {
    let modelURL = Bundle(for: DataController.self).url(forResource: "HelpMeTrain", withExtension: "momd")
    let model = modelURL.flatMap { NSManagedObjectModel(contentsOf: $0) } ?? NSManagedObjectModel()
    let container = NSPersistentContainer(name: "HelpMeTrain", managedObjectModel: model)
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [description]
    container.loadPersistentStores { _, error in
        if let error = error {
            fatalError("Failed to load in-memory store: \(error)")
        }
    }
    return container.viewContext
}

private func makeBonusState(
    context: NSManagedObjectContext,
    current: Int,
    earnEveryN: Int,
    max: Int
) -> BonusState {
    let bonus = BonusState(context: context)
    bonus.currentBalance = Int16(current)
    bonus.earnEveryN = Int16(earnEveryN)
    bonus.maxBalance = Int16(max)
    bonus.lastUpdated = Date()
    return bonus
}

private func makeDailyStepsMap(steps: [Int]) -> [Date: Int] {
    let calendar = Calendar.current
    let start = startDate(for: steps)
    return Dictionary(uniqueKeysWithValues: steps.enumerated().compactMap { offset, value in
        guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
        return (date, value)
    })
}

private func startDate(for steps: [Int]) -> Date {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return calendar.date(byAdding: .day, value: -(steps.count - 1), to: today) ?? today
}

private func dayBefore(_ date: Date) -> Date {
    let calendar = Calendar.current
    return calendar.date(byAdding: .day, value: -1, to: date) ?? date
}

private func fetchSnapshots(context: NSManagedObjectContext) -> [DailySnapshot] {
    let request = DailySnapshot.fetchRequest()
    return (try? context.fetch(request)) ?? []
}

private func fetchSnapshot(context: NSManagedObjectContext, date: Date) -> DailySnapshot? {
    let request = DailySnapshot.fetchRequest()
    request.fetchLimit = 1
    request.predicate = NSPredicate(format: "date == %@", date as NSDate)
    return try? context.fetch(request).first
}
