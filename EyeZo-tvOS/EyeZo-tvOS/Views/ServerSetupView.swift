import SwiftUI

/// Asks for the server address with a stock text field.
///
/// Shown as the app root when no server is saved, and as a full-screen cover
/// from the browser's Server button. Pressing Done on the keyboard saves the
/// address and dismisses; the browser reports any connection problem in its
/// error state, so nothing is checked here. Menu cancels without saving.
struct ServerSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var address: String

    init() {
        _address = State(initialValue: ServerURLManager.shared.serverURL?.absoluteString ?? "")
    }

    var body: some View {
        VStack(spacing: 40) {
            Text("EyeZo")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Enter the address of your video server")
                .foregroundStyle(.secondary)

            TextField("Server address", text: $address)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(save)
                .frame(maxWidth: 900)

            Text("Example: http://192.168.1.100:3000")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(60)
        // Fill the screen so the view is opaque when presented as a cover.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private func save() {
        guard let url = ServerURLManager.normalizedServerURL(from: address) else { return }
        ServerURLManager.shared.saveServerURL(url)
        dismiss()
    }
}
