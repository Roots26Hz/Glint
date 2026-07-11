import SwiftUI

/// Compact-style Bluetooth banner: device name in the left ear, device-kind
/// glyph and battery percentage in the right ear, iOS pairing-banner style
/// ("Connected" stands in when the device doesn't report battery).
struct BluetoothNotificationView: View {
    var event: BluetoothEvent
    var notchSize: CGSize

    private static let blue = Color(red: 0.04, green: 0.52, blue: 1.0)

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            
            Text(event.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 90, alignment: .center)

            Spacer()
            
            Spacer()
                .frame(width: notchSize.width)

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Self.blue)
                if let battery = event.battery {
                    Text("\(battery)%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Image(systemName: Self.batterySymbol(for: battery))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(battery <= 20 ? .red : .green)
                } else {
                    Text("Connected")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Self.blue)
                }
            }
            .frame(width: 90, alignment: .center)
            
            Spacer()
        }
        .frame(height: notchSize.height)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let battery = event.battery {
            return "\(event.name) connected, \(battery) percent battery"
        }
        return "\(event.name) connected"
    }

    private static func batterySymbol(for percent: Int) -> String {
        switch percent {
        case 88...: return "battery.100percent"
        case 63...: return "battery.75percent"
        case 38...: return "battery.50percent"
        case 11...: return "battery.25percent"
        default: return "battery.0percent"
        }
    }

    private var symbol: String {
        switch event.kind {
        case .headphones: return "headphones"
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse.fill"
        case .generic: return "dot.radiowaves.left.and.right"
        }
    }
}
