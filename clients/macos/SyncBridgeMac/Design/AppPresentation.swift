// AppPresentation.swift — Popover vs standalone window presentation.

import SwiftUI

enum AppPresentationMode {
    case popover
    case window
}

private struct AppPresentationModeKey: EnvironmentKey {
    static let defaultValue: AppPresentationMode = .popover
}

extension EnvironmentValues {
    var appPresentationMode: AppPresentationMode {
        get { self[AppPresentationModeKey.self] }
        set { self[AppPresentationModeKey.self] = newValue }
    }
}

extension View {
    func appPresentationMode(_ mode: AppPresentationMode) -> some View {
        environment(\.appPresentationMode, mode)
    }
}
