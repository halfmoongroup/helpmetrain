import Foundation
import HealthKit

final class HealthKitManager {
    private let healthStore = HKHealthStore()

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isHealthDataAvailable else { return false }

        let readTypes = Set<HKObjectType>([
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .heartRate)
        ].compactMap { $0 })

        return await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    func fetchTodaySteps() async -> Int {
        let value = await fetchCumulativeSum(for: .stepCount, unit: .count())
        return Int(value.rounded())
    }

    func fetchActiveEnergyToday() async -> Double {
        await fetchCumulativeSum(for: .activeEnergyBurned, unit: .kilocalorie())
    }

    func fetchDistanceTodayMiles() async -> Double {
        await fetchCumulativeSum(for: .distanceWalkingRunning, unit: .mile())
    }

    func fetchRecentHeartRate(withinMinutes minutes: Int) async -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }

        let now = Date()
        let startDate = Calendar.current.date(byAdding: .minute, value: -minutes, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: Int(bpm.rounded()))
            }

            healthStore.execute(query)
        }
    }

    func fetchDailyStepsLast7Days() async -> [Int] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return Array(repeating: 0, count: 7)
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let interval = DateComponents(day: 1)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startOfToday,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                guard let results = results else {
                    continuation.resume(returning: Array(repeating: 0, count: 7))
                    return
                }

                var values: [Int] = []
                for offset in 0..<7 {
                    let dayStart = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
                    let stats = results.statistics(for: dayStart)
                    let sum = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    values.append(Int(sum.rounded()))
                }

                continuation.resume(returning: values)
            }

            healthStore.execute(query)
        }
    }

    func fetchWeeklyTotalsLast7Blocks() async -> [Int] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return Array(repeating: 0, count: 7)
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let startDate = calendar.date(byAdding: .day, value: -48, to: startOfToday) ?? startOfToday
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endOfToday, options: .strictStartDate)
        let interval = DateComponents(day: 7)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startOfToday,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                guard let results = results else {
                    continuation.resume(returning: Array(repeating: 0, count: 7))
                    return
                }

                var values: [Int] = []
                for blockOffset in 0..<7 {
                    let blockStart = calendar.date(byAdding: .day, value: -(6 - blockOffset) * 7, to: startOfToday) ?? startOfToday
                    let stats = results.statistics(for: blockStart)
                    let sum = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    values.append(Int(sum.rounded()))
                }

                continuation.resume(returning: values)
            }

            healthStore.execute(query)
        }
    }

    func fetchWeeklyTotalsRolling7Days() async -> (steps: Int, energyKcal: Int, distanceMiles: Double) {
        async let steps = fetchRollingSum(for: .stepCount, unit: .count())
        async let energy = fetchRollingSum(for: .activeEnergyBurned, unit: .kilocalorie())
        async let distance = fetchRollingSum(for: .distanceWalkingRunning, unit: .mile())

        let results = await (steps, energy, distance)
        return (
            Int(results.0.rounded()),
            Int(results.1.rounded()),
            results.2
        )
    }

    func fetchDailySteps(from startDate: Date, to endDate: Date) async -> [Date: Int] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return [:]
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: end) ?? endDate
        let predicate = HKQuery.predicateForSamples(withStart: start, end: endExclusive, options: .strictStartDate)
        let interval = DateComponents(day: 1)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                guard let results = results else {
                    continuation.resume(returning: [:])
                    return
                }

                var values: [Date: Int] = [:]
                var current = start
                while current <= end {
                    let sum = results.statistics(for: current)?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    values[current] = Int(sum.rounded())
                    guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                    current = next
                }

                continuation.resume(returning: values)
            }

            healthStore.execute(query)
        }
    }

    private func fetchRollingSum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let sum = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }

    private func fetchCumulativeSum(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let sum = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }
}
