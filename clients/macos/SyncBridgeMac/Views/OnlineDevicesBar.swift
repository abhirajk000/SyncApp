// OnlineDevicesBar.swift — Online device chips on home.

import SwiftUI

struct OnlineDevicesBar: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    private var others: [DeviceResponse] {
        let currentId = KeychainService.shared.deviceId
        return appState.devices.filter { $0.id != currentId }
    }

    var body: some View {
        if others.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Text("ONLINE DEVICES")
                    .font(DS.Font.label())
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Space.sm) {
                        ForEach(others) { device in
                            deviceChip(device)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    private func deviceChip(_ device: DeviceResponse) -> some View {
        HStack(spacing: DS.Space.xs) {
            Circle()
                .fill(DS.Color.success)
                .frame(width: 6, height: 6)
            Image(systemName: platformIcon(device.platform))
                .font(.system(size: 11, weight: .semibold))
            Text(device.name)
                .font(DS.Font.label())
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Space.sm)
        .padding(.vertical, DS.Space.xs + 2)
        .foregroundStyle(DS.Color.textAdaptive(colorScheme))
        .background(DS.Color.cardAdaptive(colorScheme), in: Capsule())
        .overlay(Capsule().stroke(DS.Color.borderAdaptive(colorScheme).opacity(0.4)))
    }

    private func platformIcon(_ platform: String) -> String {
        switch platform {
        case "macos": return "desktopcomputer"
        case "ios": return "iphone"
        case "android": return "candybarphone"
        default: return "laptopcomputer"
        }
    }
}
