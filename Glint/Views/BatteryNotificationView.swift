import SwiftUI

/// Compact-style battery notification: label in the left ear, battery glyph
/// and percentage in the right ear, iOS charging-banner style.
struct BatteryNotificationView: View {
    var event: BatteryEvent
    var notchSize: CGSize

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .frame(width: 90, alignment: .center)

            Spacer()
            
            Spacer()
                .frame(width: notchSize.width)

            Spacer()

            HStack(spacing: 5) {
                Text("\(percentage)%")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(tint)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint)
            }
            .frame(width: 90, alignment: .center)
            
            Spacer()
        }
        .frame(height: notchSize.height)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(percentage) percent")
    }

    private var percentage: Int {
        switch event {
        case .pluggedIn(let p), .unplugged(let p), .lowBattery(let p),
             .fullyCharged(let p), .chargeLimited(let p):
            return p
        }
    }

    private var label: String {
        switch event {
        case .pluggedIn: return "Charging"
        case .unplugged: return "On Battery"
        case .lowBattery: return "Low Battery"
        case .fullyCharged: return "Fully Charged"
        case .chargeLimited: return "Charge Limit"
        }
    }

    private var tint: Color {
        switch event {
        case .pluggedIn, .fullyCharged, .chargeLimited: return .green
        case .unplugged: return .white
        case .lowBattery: return percentage <= 10 ? .red : .orange
        }
    }

    private var symbol: String {
        switch event {
        case .pluggedIn, .fullyCharged:
            return "battery.100percent.bolt"
        case .unplugged, .lowBattery, .chargeLimited:
            let level = max(0, min(100, percentage))
            let bucket = [0, 25, 50, 75, 100].min { abs($0 - level) < abs($1 - level) } ?? 100
            return "battery.\(bucket)percent"
        }
    }
}
