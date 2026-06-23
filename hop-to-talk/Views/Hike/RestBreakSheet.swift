import SwiftUI

struct RestBreakSheet: View {
    @Bindable var viewModel: HikingSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var restMinutes = 15

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Istirahat")
                    .font(.title.bold())
                Text("Radio dimatikan sementara untuk hemat baterai. Lanjutkan saat siap bergerak lagi.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Stepper("Timer \(restMinutes) menit", value: $restMinutes, in: 5...60, step: 5)
                    .padding()

                Spacer()

                Button("Mulai istirahat") {
                    Task {
                        await viewModel.beginRest()
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 56)
                .padding()
            }
            .navigationTitle("Istirahat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
            }
        }
    }
}
