import SwiftUI

/// Compact-style battery notification: label in the left ear, battery glyph
/// and percentage in the right ear, iOS charging-banner style.
struct BatteryNotificationView: View {
    var event: BatteryEvent
    var notchSize: CGSize

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .padding(.leading, 15)

            Spacer(minLength: notchSize.width - 40)

            HStack(spacing: 5) {
                Text("\(percentage)%")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(tint)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint)
            }
            .padding(.trailing, 15)
        }
        .frame(height: notchSize.height)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(percentage) percent")
    }

    private var percentage: Int {
        switch event {
        case .pluggedIn(let p), .unplugged(let p), .lowBattery(let p): return p
        }
    }

    private var label: String {
        switch event {
        case .pluggedIn: return "Charging"
        case .unplugged: return "On Battery"
        case .lowBattery: return "Low Battery"
        }
    }

    private var tint: Color {
        switch event {
        case .pluggedIn: return .green
        case .unplugged: return .white
        case .lowBattery: return percentage <= 10 ? .red : .orange
        }
    }

    private var symbol: String {
        switch event {
        case .pluggedIn:
            return "battery.100percent.bolt"
        case .unplugged, .lowBattery:
            let level = max(0, min(100, percentage))
            let bucket = [0, 25, 50, 75, 100].min { abs($0 - level) < abs($1 - level) } ?? 100
            return "battery.\(bucket)percent"
        }
    }
}
