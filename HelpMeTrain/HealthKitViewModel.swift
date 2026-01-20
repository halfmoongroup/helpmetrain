import Foundation

@MainActor
final class HealthKitViewModel: ObservableObject {
    @Published var isHealthDataAvailable = true
    @Published var isAuthorized = false
    @Published var todaySteps = 0
    @Published var activeEnergyKcal = 0
    @Published var distanceMiles: Double = 0
    @Published var heartRate: Int?
    @Published var last7DaysSteps: [Int] = Array(repeating: 0, count: 7)
    @Published var last7WeekBlocksSteps: [Int] = Array(repeating: 0, count: 7)
    @Published var weekStepsTotal = 0
    @Published var weekEnergyKcal = 0
    @Published var weekDistanceMiles: Double = 0
    @Published var statusMessage: String?

    private let healthKit = HealthKitManager()
    private var recentHRWindowMinutes = 10

    func requestAndLoad(recentHRMinutes: Int) async {
        recentHRWindowMinutes = max(1, recentHRMinutes)
        isHealthDataAvailable = healthKit.isHealthDataAvailable
        guard isHealthDataAvailable else {
            statusMessage = "Health data is not available on this device."
            resetData()
            return
        }

        if !isAuthorized {
            isAuthorized = await healthKit.requestAuthorization()
        }

        guard isAuthorized else {
            statusMessage = "Health access not granted."
            resetData()
            return
        }

        await loadData()
    }

    func refresh(recentHRMinutes: Int) {
        Task {
            await requestAndLoad(recentHRMinutes: recentHRMinutes)
        }
    }

    private func loadData() async {
        async let steps = healthKit.fetchTodaySteps()
        async let daily = healthKit.fetchDailyStepsLast7Days()
        async let energy = healthKit.fetchActiveEnergyToday()
        async let distance = healthKit.fetchDistanceTodayMiles()
        async let heartRate = healthKit.fetchRecentHeartRate(withinMinutes: recentHRWindowMinutes)
        async let weekBlocks = healthKit.fetchWeeklyTotalsLast7Blocks()
        async let weekTotals = healthKit.fetchWeeklyTotalsRolling7Days()

        let results = await (steps, daily, energy, distance, heartRate, weekBlocks, weekTotals)
        todaySteps = results.0
        last7DaysSteps = results.1
        activeEnergyKcal = Int(results.2.rounded())
        distanceMiles = results.3
        self.heartRate = results.4
        last7WeekBlocksSteps = results.5
        weekStepsTotal = results.6.steps
        weekEnergyKcal = results.6.energyKcal
        weekDistanceMiles = results.6.distanceMiles
        statusMessage = nil
    }

    private func resetData() {
        todaySteps = 0
        activeEnergyKcal = 0
        distanceMiles = 0
        heartRate = nil
        last7DaysSteps = Array(repeating: 0, count: 7)
        last7WeekBlocksSteps = Array(repeating: 0, count: 7)
        weekStepsTotal = 0
        weekEnergyKcal = 0
        weekDistanceMiles = 0
    }

    func fetchDailySteps(from startDate: Date, to endDate: Date) async -> [Date: Int] {
        await healthKit.fetchDailySteps(from: startDate, to: endDate)
    }
}
