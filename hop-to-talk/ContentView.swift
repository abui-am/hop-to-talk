import SwiftUI

struct RootView: View {
    @State private var viewModel = HikingSessionViewModel()

    var body: some View {
        Group {
            switch viewModel.phase {
            case .onboarding:
                OnboardingFlowView(viewModel: viewModel)
            case .trailhead:
                TrailheadSetupFlow(viewModel: viewModel)
            case .activeHike:
                ActiveHikeView(viewModel: viewModel)
            case .summary:
                HikeSummaryView(viewModel: viewModel) {
                    viewModel.phase = .trailhead
                    viewModel.trailheadStep = .config
                    viewModel.hikeStartDate = nil
                    viewModel.pttCount = 0
                    viewModel.isResting = false
                    viewModel.statusMessage = "Siap di basecamp"
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
}
