import CoreGraphics

struct GraphNormalizer {
    static func paddedValues(_ values: [Int], count: Int) -> [Int] {
        guard count > 0 else { return [] }
        if values.count >= count {
            return Array(values.suffix(count))
        }
        let padValue = values.first ?? 0
        let padding = Array(repeating: padValue, count: count - values.count)
        return padding + values
    }

    static func normalizedPoints(values: [Int], size: CGSize) -> [CGPoint] {
        guard let minValue = values.min(), let maxValue = values.max() else { return [] }
        let step = size.width / CGFloat(max(values.count - 1, 1))

        if minValue == maxValue {
            return values.enumerated().map { index, _ in
                let x = CGFloat(index) * step
                let y = size.height * 0.5
                return CGPoint(x: x, y: y)
            }
        }

        let range = maxValue - minValue
        return values.enumerated().map { index, value in
            let normalized = CGFloat(value - minValue) / CGFloat(range)
            let x = CGFloat(index) * step
            let y = size.height - (normalized * size.height)
            return CGPoint(x: x, y: y)
        }
    }
}
