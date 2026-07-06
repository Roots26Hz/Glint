import SwiftUI

/// Compact-style Bluetooth banner: device name in the left ear, device-kind
/// glyph and "Connected" in the right ear, iOS pairing-banner style.
struct BluetoothNotificationView: View {
    var event: BluetoothEvent
    var notchSize: CGSize

    private static let blue = Color(red: 0.04, green: 0.52, blue: 1.0)

    var body: some View {
        HStack(spacing: 0) {
            Text(event.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 105, alignment: .leading)
                .padding(.leading, 15)

            Spacer(minLength: notchSize.width - 40)

            HStack(spacing: 5) {
                Text("Connected")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Self.blue)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Self.blue)
            }
            .padding(.trailing, 15)
        }
        .frame(height: notchSize.height)
        .accessibilityElement()
        .accessibilityLabel("\(event.name) connected")
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
