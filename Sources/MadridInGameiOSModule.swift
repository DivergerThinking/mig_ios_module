//// The Swift Programming Language
//// https://docs.swift.org/swift-book

import SwiftUI

public struct MadridInGameiOSModule: View {
    @StateObject private var viewModel: MadridInGameiOSViewModel
    @Environment(\.presentationMode) var presentationMode
    
    /// Opens the Madrid in Game esports module for the user signed in on the host app.
    ///
    /// The SDK exchanges `idToken` for a web session and, when that session expires, calls
    /// `idTokenProvider` to get a fresh token. The user's identity (email, name, DNI…) comes
    /// from that session, so the host does not pass it.
    ///
    /// ```swift
    /// MadridInGameiOSModule(
    ///     idToken: result.idToken,
    ///     idTokenProvider: { forceRefresh in try await auth.idToken(forceRefresh: forceRefresh) }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - idToken: Azure AD B2C `id_token` of the current MSAL session, unmodified.
    ///   - idTokenProvider: Called by the SDK when it needs a new `id_token`. Throw if the user must sign in again.
    ///   - logoMIG: Logo shown in the module header.
    ///   - qrMiddleLogo: Image drawn in the middle of reservation QR codes.
    ///   - isPreRelease: `true` to use the PRE environment.
    public init(idToken: String,
                idTokenProvider: @escaping MIGIdTokenProvider,
                logoMIG: UIImage? = nil,
                qrMiddleLogo: UIImage? = nil,
                isPreRelease: Bool = false) {
        if let logo = logoMIG {
            UserDefaults.saveLogoMIG(logo)
        }
        if let logo = qrMiddleLogo {
            UserDefaults.saveQrMiddleLogo(logo)
        }
        _viewModel = StateObject(wrappedValue: MadridInGameiOSViewModel(
            idToken: idToken,
            idTokenProvider: idTokenProvider,
            isPro: !isPreRelease,
            openCompetitions: false
        ))
    }

    public var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.black, Color.black, Color.black, Color.black.opacity(0.9)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(.all)
            
            if viewModel.isLoading {
                LoadingView(message: "Preparando tu experiencia...".localized)
            } else if let error = viewModel.error {
                errorView(error)
            } else if let user = viewModel.user {
                contentView(user: user)
            }
        }
        .onAppear {
            viewModel.initializeModule()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
    
    private func errorView(_ error: MIGAuthError) -> some View {
        VStack(spacing: 12) {
            Text("Error al cargar el módulo".localized)
                .foregroundColor(.red)
            Text(error.localizedMessage)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                if error.isRetryable {
                    Button("common.retry".localized) { viewModel.retry() }
                        .foregroundColor(.cyan)
                }
                Button("common.close".localized) { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(.white)
            }
        }
        .padding()
    }

    private func contentView(user: UserModel) -> some View {
        VStack {
            topBarView
        }
    }
    
    private var topBarView: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 18)
                        .foregroundStyle(.white)
                }
                .padding(.trailing, 10)
                
                tabButton(title: "dashboard.layout.dashboard".localized, tab: 0)
                if !viewModel.getUserTeams().isEmpty {
                    tabButton(title: "dashboard.layout.teams".localized, tab: 1)
                }
                tabButton(title: "competitions.heading".localized, tab: 2)
            }
            .padding(.horizontal, 10)
            
            if viewModel.selectedTab == 0 {
                DashboardScreenView()
            } else if viewModel.selectedTab == 1 {
                TeamsScreenView()
            } else {
                NavigationStack {
                    CompetitionsView(viewModel: CompetitionsViewModel())
                }
            }
        }
    }
    
    private func tabButton(title: String, tab: Int) -> some View {
        Button(action: { viewModel.selectTab(tab) }) {
            VStack {
                Text(title)
                    .foregroundColor(viewModel.selectedTab == tab ? .cyan : .white)
                    .font(.madridInGameiOSFont(size: 15))
                Rectangle()
                    .fill(viewModel.selectedTab == tab ? Color.cyan : Color.clear)
                    .frame(height: 3)
            }
        }
    }
}
