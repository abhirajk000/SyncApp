import SwiftUI

enum SendRoute {
    case landing, cloud, localSend
}

struct SendSectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var route: SendRoute = .landing

    var body: some View {
        Group {
            switch route {
            case .landing:
                SendLandingView(
                    onCloud: { route = .cloud },
                    onWifi: { route = .localSend }
                )
            case .cloud:
                VStack(spacing: 0) {
                    HStack {
                        GhostButton(title: "← Back") { route = .landing }
                        Spacer()
                    }
                    .padding(.horizontal, SyncTokens.space4)
                    .padding(.top, SyncTokens.space4)
                    SendView()
                }
            case .localSend:
                LocalSendFlowView(onBack: { route = .landing })
            }
        }
    }
}
