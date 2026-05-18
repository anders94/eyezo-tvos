import SwiftUI

struct ServerSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var serverURLManager = ServerURLManager.shared
    @State private var urlInput = ""
    @State private var isValidating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 60) {
                Spacer()

                VStack(spacing: 30) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.blue)

                    Text("EyeZo")
                        .font(.system(size: 60, weight: .bold))

                    Text("Connect to your video server")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 30) {
                    TextField("Server URL", text: $urlInput)
                        .font(.title3)
                        .padding(20)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.horizontal, 80)
                        .onChange(of: urlInput) {
                            errorMessage = nil
                        }

                    Text("Example: http://192.168.1.100:3000")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.title3)
                            .foregroundColor(.red)
                            .padding(.horizontal, 80)
                    }

                    Button(action: validateAndSave) {
                        HStack(spacing: 20) {
                            if isValidating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            } else {
                                Text("Connect")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: 600)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 40)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    .buttonStyle(.plain)
                    .disabled(urlInput.isEmpty || isValidating)
                    .padding(.horizontal, 80)
                }

                Spacer()
            }
            .padding(60)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            // Pre-populate with current server URL if available, otherwise start with http://
            if urlInput.isEmpty {
                if let currentURL = serverURLManager.serverURL {
                    urlInput = currentURL.absoluteString
                } else {
                    urlInput = "http://"
                }
            }
        }
    }

    private func validateAndSave() {
        var urlString = urlInput.trimmingCharacters(in: .whitespaces)

        // Auto-add http:// if no scheme is provided
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            urlString = "http://" + urlString
        }

        // Remove trailing slash
        if urlString.hasSuffix("/") {
            urlString.removeLast()
        }

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL format"
            return
        }

        isValidating = true
        errorMessage = nil

        Task {
            let isValid = await serverURLManager.validateServerURL(url)

            await MainActor.run {
                isValidating = false

                if isValid {
                    serverURLManager.saveServerURL(url)
                    dismiss()
                } else {
                    errorMessage = "Cannot connect to server. Please check the URL and try again."
                }
            }
        }
    }
}
