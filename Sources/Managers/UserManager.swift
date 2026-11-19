//
//  UserManager.swift
//  Pods
//
//  Created by Hamza El Hamdaoui on 27/1/25.
//

import Foundation

/// In-memory state of the signed-in member. Identity comes from the web session, never from the host.
class UserManager {
    static let shared = UserManager()

    private var user: UserModel?

    private init() {}

    func setUser(user: UserModel) {
        self.user = user
    }

    func getUser() -> UserModel? {
        return user
    }

    func clear() {
        user = nil
    }

    func setSelectedTeam(_ team: TeamModelReal) {
        self.user?.selectedTeam = team
    }

    func getSelectedTeam() -> TeamModelReal? {
        return self.user?.selectedTeam
    }

    func setAllTeamsUser(_ teams: [TeamModelReal]) {
        self.user?.teamsResponse = teams
    }

    struct TeamResponse: Codable {
        let data: [TeamModelReal]
    }

    struct TrainingsResponseModel: Codable {
        let data: [TrainingsModel]
    }

    func setDNI(_ dni: String) {
        self.user?.dni = dni
    }

    /// Loads the member from the session profile plus its teams. Keeps the selected team if it still exists.
    func load(profile: SessionProfile) async throws {
        let teams = try await fetchTeams(userId: profile.id)
        let previousTeamId = user?.id == profile.id ? user?.selectedTeam?.id : nil
        var loaded = UserModel(profile: profile)
        loaded.teamsResponse = teams
        loaded.selectedTeam = teams.first { $0.id == previousTeamId }
        user = loaded
    }

    func fetchTeamsByUser(userId: String, completion: @escaping (Result<[TeamModelReal], Error>) -> Void) {
        Task {
            do {
                completion(.success(try await fetchTeams(userId: userId)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func fetchTeams(userId: String) async throws -> [TeamModelReal] {
        let parameters = [
            "filter[users][users_id][_eq]": userId,
            "fields": "id,name,description,picture,apply_membership,status,discord,users.roles.name,users.users_id.id,users.users_id.username,users.users_id.avatar,users.users_id.email,competitions.competitions_id,date_edited",
        ]
        let response: TeamResponse = try await DirectusService.shared.request(
            endpoint: "teams",
            method: .GET,
            parameters: parameters
        )
        return response.data
    }
}
