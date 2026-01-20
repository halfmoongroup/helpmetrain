import CoreData

@objc(BonusState)
public final class BonusState: NSManagedObject {
    @NSManaged public var currentBalance: Int16
    @NSManaged public var maxBalance: Int16
    @NSManaged public var earnEveryN: Int16
    @NSManaged public var lastUpdated: Date
}

extension BonusState {
    var currentBalanceValue: Int {
        Int(currentBalance)
    }

    var maxBalanceValue: Int {
        Int(maxBalance)
    }

    var earnEveryNValue: Int {
        Int(earnEveryN)
    }
}

extension BonusState {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BonusState> {
        NSFetchRequest<BonusState>(entityName: "BonusState")
    }
}
