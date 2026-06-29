import SwiftUI

enum SendRoute {
    case landing, cloud, localSend
}

struct SendSectionView: View {
    @EnvironmentObject var localSendManager: LocalSendManager
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
                        AppButton(title: "← Back", variant: .ghost) { route = .landing }
                        Spacer()
                    }
                    .padding(DS.Space.md)
                    SendTabView()
                }
            case .localSend:
                LocalSendFlowView(onBack: { route = .landing })
                    .environmentObject(localSendManager)
            }
        }
    }
}
