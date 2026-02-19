import SwiftUI
import OneSignalFramework

struct LiveActivitySection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    @State private var activityId: String = ""

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Live Activities", tooltipKey: "liveActivities")

            CardContainer {
                HStack {
                    Text("Activity ID")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    TextField("Enter activity ID", text: $activityId)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            ActionButton(title: "Enter Live Activity") {
                viewModel.enterLiveActivity(activityId: activityId)
            }
            .padding(.top, 12)

            OutlineActionButton(title: "Exit Live Activity") {
                viewModel.exitLiveActivity(activityId: activityId)
            }
            .padding(.top, 8)
        }
    }
}

#Preview {
    LiveActivitySection()
        .padding()
        .background(Color(.systemGroupedBackground))
        .environmentObject(OneSignalViewModel())
}
