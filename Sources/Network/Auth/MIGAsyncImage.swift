//
//  MIGAsyncImage.swift
//  MadridInGameiOSModule
//

import SwiftUI

/// `AsyncImage` replacement that downloads through the SDK client, so private gateway assets
/// (e.g. reservation QR codes) carry the member session cookie. Same phase-based API.
struct MIGAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content
    @State private var phase: AsyncImagePhase = .empty

    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        phase = .empty
        guard let url else { phase = .failure(URLError(.badURL)); return }
        do {
            let (data, response) = try await MIGHTTPClient.shared.send(URLRequest(url: url))
            guard (200...299).contains(response.statusCode), let image = UIImage(data: data) else {
                phase = .failure(URLError(.badServerResponse)); return
            }
            phase = .success(Image(uiImage: image))
        } catch {
            phase = .failure(error)
        }
    }
}
