//
//  MadridInGameViewModel.swift
//  Pods
//
//  Created by Arnau Rivas Rivas on 4/2/25.
//

import SwiftUI
import FontBlaster

@MainActor
final class MadridInGameiOSViewModel: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var isLoading: Bool = true
    @Published var user: UserModel?
    @Published var error: MIGAuthError?
    @Published var openCompetitions: Bool

    var errorMessage: String? { error?.localizedMessage }

    private let idTokenProvider: MIGIdTokenProvider
    private var initialIdToken: String?
    private let client: MIGHTTPClient
    private let userManager: UserManager
    private let environmentManager: EnvironmentManager
    private var loadTask: Task<Void, Never>?
    private var hasOpenedSession = false

    private var originalStyle: UIUserInterfaceStyle?

    init(idToken: String,
         idTokenProvider: @escaping MIGIdTokenProvider,
         isPro: Bool,
         openCompetitions: Bool,
         client: MIGHTTPClient = .shared,
         userManager: UserManager = .shared) {
        self.initialIdToken = idToken
        self.idTokenProvider = idTokenProvider
        self.client = client
        self.userManager = userManager
        self.environmentManager = EnvironmentManager(isPro: isPro)
        MIGEnvironment.current = environmentManager.currentEnvironment
        self.openCompetitions = openCompetitions

        Logger.shared.isEnabled = !isPro
        UserDefaults.removeLegacyAccessToken()
        if self.openCompetitions {
            self.selectTab(2)
        }

        Task.detached { [envManager = self.environmentManager] in
            await DirectusService.shared.configure(with: envManager)
        }
        FontManager().loadCustomFonts()
    }

    /// Debe ejecutarse en onAppear, nunca durante el init: mutar la ventana
    /// mientras SwiftUI construye la jerarquía inicial invalida la vista y
    /// provoca que se cree un segundo ViewModel huérfano (loading infinito en iOS 26).
    private func applyDarkModeOverride() {
        guard originalStyle == nil else { return }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let window = windowScene.windows.first {
                self.originalStyle = window.overrideUserInterfaceStyle
                window.overrideUserInterfaceStyle = .dark
            }
        }
    }

    func initializeModule() {
        applyDarkModeOverride()
        guard loadTask == nil else { return }
        loadTask = Task { [weak self] in
            await self?.load()
            self?.loadTask = nil
        }
    }

    func retry() {
        error = nil
        isLoading = true
        initializeModule()
    }

    private func load() async {
        do {
            let profile = try await currentProfile()
            TextContentService().fetchTextContent()
            try await userManager.load(profile: profile)
            user = userManager.getUser()
            error = nil
        } catch {
            self.error = MIGAuthError.from(error)
        }
        isLoading = false
    }

    /// First load opens the session with the host's token; later loads (tab switches) refresh it.
    private func currentProfile() async throws -> SessionProfile {
        if let token = initialIdToken {
            initialIdToken = nil
            await client.reset()
            await DirectusService.shared.configure(with: environmentManager)
            await client.session.setProvider(idTokenProvider)
            await client.session.onFailure { [weak self] failure in
                Task { @MainActor in self?.error = failure }
            }
            let profile = try await client.session.establish(idToken: token)
            hasOpenedSession = true
            return profile
        }
        if !hasOpenedSession {
            // Session never opened (e.g. first attempt failed before reaching the server).
            let token: String
            do { token = try await idTokenProvider(false) } catch { throw MIGAuthError.sessionExpired }
            let profile = try await client.session.establish(idToken: token)
            hasOpenedSession = true
            return profile
        }
        return try await fetchSessionProfile()
    }

    private func fetchSessionProfile() async throws -> SessionProfile {
        guard let url = URL(string: environmentManager.currentEnvironment.sessionURL) else { throw MIGAuthError.unexpected }
        let (data, response) = try await client.send(URLRequest(url: url))
        guard (200...299).contains(response.statusCode) else {
            throw NetworkError.serverError(statusCode: response.statusCode)
        }
        guard let profile = try JSONDecoder().decode(SessionResponse.self, from: data).user else {
            throw MIGAuthError.unexpected
        }
        return profile
    }

    func selectTab(_ tab: Int) {
        selectedTab = tab
        if tab == 0 || tab == 1 {
            initializeModule()
        }
    }

    func getUserTeams() -> [TeamModelReal] {
        return userManager.getUser()?.teamsResponse ?? []
    }

    func onDisappear() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let window = windowScene.windows.first {
                window.overrideUserInterfaceStyle = self.originalStyle ?? .dark
            }
        }
    }
}
