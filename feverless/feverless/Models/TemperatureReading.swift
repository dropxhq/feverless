import Foundation
import SwiftData

@Model
final class TemperatureReading {
    var positionRaw: String = ""
    var value: Double = 0.0

    init(positionRaw: String, value: Double) {
        self.positionRaw = positionRaw
        self.value = value
    }

    func isFever(catalog: TemperaturePositionCatalog = .shared) -> Bool {
        let threshold = catalog.find(positionRaw)?.feverThreshold ?? 37.5
        return value >= threshold
    }
}
