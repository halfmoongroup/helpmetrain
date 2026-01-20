import CoreData

@objc(Settings)
public final class Settings: NSManagedObject {
    @NSManaged public var dailyStepTarget: Int32
    @NSManaged public var recentHRWindowMinutes: Int16
}

extension Settings {
    var dailyStepTargetValue: Int {
        Int(dailyStepTarget)
    }

    var recentHRWindowMinutesValue: Int {
        Int(recentHRWindowMinutes)
    }
}

extension Settings {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Settings> {
        NSFetchRequest<Settings>(entityName: "Settings")
    }
}
