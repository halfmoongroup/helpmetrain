import CoreData

@objc(DailySnapshot)
public final class DailySnapshot: NSManagedObject {
    @NSManaged public var date: Date
    @NSManaged public var goalSteps: Int32
    @NSManaged public var actualSteps: Int32
    @NSManaged public var usedBonus: Bool
}

extension DailySnapshot {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailySnapshot> {
        NSFetchRequest<DailySnapshot>(entityName: "DailySnapshot")
    }
}

extension DailySnapshot {
    var goalStepsValue: Int {
        Int(goalSteps)
    }

    var actualStepsValue: Int {
        Int(actualSteps)
    }
}
