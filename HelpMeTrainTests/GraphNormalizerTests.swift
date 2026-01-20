import CoreGraphics
import Testing
@testable import HelpMeTrain

struct GraphNormalizerTests {

    @Test func normalizedPointsFlatLine() async throws {
        let size = CGSize(width: 100, height: 80)
        let values = [5, 5, 5, 5]
        let points = GraphNormalizer.normalizedPoints(values: values, size: size)

        #expect(points.count == values.count)
        for point in points {
            #expect(point.y == size.height * 0.5)
        }
    }

    @Test func normalizedPointsRange() async throws {
        let size = CGSize(width: 100, height: 100)
        let values = [0, 10]
        let points = GraphNormalizer.normalizedPoints(values: values, size: size)

        #expect(points.count == 2)
        #expect(points[0].y == size.height)
        #expect(points[1].y == 0)
    }

    @Test func paddedValuesUsesFirstValue() async throws {
        let values = [3, 4]
        let padded = GraphNormalizer.paddedValues(values, count: 5)

        #expect(padded.count == 5)
        #expect(padded.prefix(3).allSatisfy { $0 == 3 })
        #expect(padded.suffix(2) == values)
    }
}
