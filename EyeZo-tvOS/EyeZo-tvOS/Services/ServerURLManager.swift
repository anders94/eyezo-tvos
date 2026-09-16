import Foundation
import Combine

class ServerURLManager: ObservableObject {
    static let shared = ServerURLManager()

    private let userDefaultsKey = "serverURL"

    @Published var serverURL: URL? {
        didSet {
            if let url = serverURL {
                UserDefaults.standard.set(url.absoluteString, forKey: userDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            }
        }
    }

    private init() {
        if let urlString = UserDefaults.standard.string(forKey: userDefaultsKey),
           let url = URL(string: urlString) {
            self.serverURL = url
        }
    }

    func saveServerURL(_ url: URL) {
        self.serverURL = url
    }

    /// Turns what the user typed into a server URL, or nil if it can't be one.
    ///
    /// Trims whitespace, assumes `http://` when no scheme is given, drops a
    /// trailing slash, and requires a host. Kept pure so it can be unit-tested.
    static func normalizedServerURL(from input: String) -> URL? {
        var string = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !string.isEmpty else { return nil }

        let lowercased = string.lowercased()
        if !lowercased.hasPrefix("http://") && !lowercased.hasPrefix("https://") {
            string = "http://" + string
        }

        while string.hasSuffix("/") {
            string.removeLast()
        }

        guard let components = URLComponents(string: string),
              let host = components.host, !host.isEmpty else {
            return nil
        }
        return components.url
    }
}
