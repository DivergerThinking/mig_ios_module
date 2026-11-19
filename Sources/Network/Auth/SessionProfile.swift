//
//  SessionProfile.swift
//  MadridInGameiOSModule
//

import Foundation

/// Body of `POST|GET /api/member/session/`.
struct SessionResponse: Decodable {
    let authenticated: Bool?
    let user: SessionProfile?
}

/// Profile of the signed-in member as returned by the web session (SELF_FIELDS on the server).
struct SessionProfile: Decodable, Equatable {
    let id: String
    var status: String?
    var username: String?
    var email: String?
    var dni: String?
    var firstName: String?
    var lastName: String?
    var phone: String?
    /// The server returns a gateway path (`/api/data/assets/<id>`), not a bare file id.
    var avatar: String?
    var reservesAllowed: Int?

    enum CodingKeys: String, CodingKey {
        case id, status, username, email, dni, phone, avatar
        case firstName = "first_name"
        case lastName = "last_name"
        case reservesAllowed = "reserves_allowed"
    }

    init(id: String, status: String? = nil, username: String? = nil, email: String? = nil, dni: String? = nil,
         firstName: String? = nil, lastName: String? = nil, phone: String? = nil, avatar: String? = nil,
         reservesAllowed: Int? = nil) {
        self.id = id
        self.status = status
        self.username = username
        self.email = email
        self.dni = dni
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.avatar = avatar
        self.reservesAllowed = reservesAllowed
    }

    /// File id of the avatar, whatever form the server used.
    var avatarId: String? {
        guard let avatar else { return nil }
        let trimmed = avatar.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let id = trimmed.split(separator: "/").last.map(String.init) ?? ""
        return id.isEmpty ? nil : id
    }
}

/// Directus-style error envelope: `{"errors":[{"extensions":{"code":"..."}}]}`.
struct GatewayErrorEnvelope: Decodable {
    struct GatewayError: Decodable {
        struct Extensions: Decodable { let code: String? }
        let extensions: Extensions?
    }
    let errors: [GatewayError]?

    var code: String? { errors?.first?.extensions?.code }
}

extension UserModel {
    /// The web session is the only source of the member identity.
    init(profile: SessionProfile) {
        self.init(
            id: profile.id,
            status: profile.status,
            username: profile.username,
            email: profile.email,
            dni: profile.dni,
            token: nil,
            firstName: profile.firstName,
            lastName: profile.lastName,
            avatar: profile.avatarId,
            reservesAllowed: profile.reservesAllowed,
            phone: profile.phone,
            address: nil,
            trainings: nil,
            gamingSpaceReserves: nil,
            invitations: nil
        )
    }
}
