import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case networkFailure(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .networkFailure(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}

class APIService {
    func checkHealth(serverURL: URL) async throws -> Bool {
        let healthURL = serverURL.appendingPathComponent("api/health")

        do {
            let (_, response) = try await URLSession.shared.data(from: healthURL)

            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            throw NetworkError.networkFailure(error)
        }
    }

    func browse(serverURL: URL, path: String? = nil) async throws -> BrowseResponse {
        var browseURL: URL
        if let path = path, !path.isEmpty {
            browseURL = serverURL
                .appendingPathComponent("api/browse")
                .appendingPathComponent(path)
        } else {
            browseURL = serverURL.appendingPathComponent("api/browse")
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: browseURL)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            do {
                let decoder = JSONDecoder()
                let browseResponse = try decoder.decode(BrowseResponse.self, from: data)
                return browseResponse
            } catch {
                throw NetworkError.decodingError(error)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkFailure(error)
        }
    }

    func getVideoURL(serverURL: URL, videoPath: String) -> URL {
        // videoPath is already URL-encoded from the server
        // We need to construct the URL carefully to avoid double-encoding
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)!
        components.percentEncodedPath = "/api/video/\(videoPath)"
        return components.url!
    }

    func getThumbnailURL(serverURL: URL, videoPath: String) -> URL? {
        // videoPath is already URL-encoded from the server
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)!
        components.percentEncodedPath = "/api/thumbnail/\(videoPath)"
        return components.url
    }

    // MARK: - Watch Progress

    func updateWatchProgress(serverURL: URL, videoPath: String, position: Double) async throws {
        let progressURL = serverURL.appendingPathComponent("api/watch-progress")

        let update = WatchProgressUpdate(path: videoPath, position: position)
        let encoder = JSONEncoder()
        let data = try encoder.encode(update)

        var request = URLRequest(url: progressURL)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkFailure(error)
        }
    }

    func getWatchProgress(serverURL: URL, videoPath: String) async throws -> WatchProgress? {
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)!
        components.percentEncodedPath = "/api/watch-progress/\(videoPath)"

        guard let progressURL = components.url else {
            throw NetworkError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: progressURL)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                // 404 means no progress saved, return nil
                if httpResponse.statusCode == 404 {
                    return nil
                }
                throw NetworkError.serverError(httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let progress = try decoder.decode(WatchProgress.self, from: data)
            return progress
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkFailure(error)
        }
    }

    func clearWatchProgress(serverURL: URL, videoPath: String) async throws {
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)!
        components.percentEncodedPath = "/api/watch-progress/\(videoPath)"

        guard let progressURL = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: progressURL)
        request.httpMethod = "DELETE"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkFailure(error)
        }
    }
}
