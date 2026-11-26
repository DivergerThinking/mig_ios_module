import Foundation

struct TeamReservationResponse: Codable {
    let data: [TeamReservation]
}

struct TeamReservation: Codable, Identifiable {
    let id: Int
    let date: Date
    let slot: Slot
    let times: [GamingSpaceTime]

    enum CodingKeys: String, CodingKey {
        case id, date, slot, times
    }
}

struct IndividualReservationResponse: Codable {
    let data: [IndividualReservation]
}

struct IndividualReservation: Identifiable, Codable {
    let id: Int?
    let status: String?
    let slot: Slot
    let date: String
    let user: String?
    let team: String?
    let training: String?
    let qrImage: String?
    let qrValue: String?
    var times: [Time] = []
    var gamingSpaces: [GamingSpace] = []

    enum CodingKeys: String, CodingKey {
        case id, status, slot, date, user, team, training, qrImage, qrValue, times
    }
}

struct GamingSpaceResponseData: Codable {
    let data: [GamingSpace]
}

struct GamingSpace: Codable {
    let id: Int
    let translations: [Translation]
}

struct Translation: Codable {
    let description: String?
    let device: String
    let gamingSpaceId: Int
    let id: Int
    let languagesCode: String

    enum CodingKeys: String, CodingKey {
        case description, device, id
        case gamingSpaceId = "gaming_space_id"
        case languagesCode = "languages_code"
    }
}

struct Reservation: Codable {
    let id: Int?
    let status: String?
    let slot: Slot
    let date: Date
    let user: String?
    let team: String?
    let training: String?
    let qrImage: String?
    let qrValue: String?
    var times: [GamingSpaceTime]
    let peripheralLoans: [Int]?

    enum CodingKeys: String, CodingKey {
        case id, status, slot, date, user, team, training, qrImage, qrValue, times
        case peripheralLoans = "peripheral_loans"
    }
}

// MARK: - Modelos para Training

struct TrainingRequest {
    let status: String
    let type: String
    let startDate: String
    let time: String
    let teamId: String
    let notes: String
    let playerIds: [String]
    let reserveIds: [Int]
}

struct TrainingResponseModel: Codable {
    let data: TrainingResponse
}

struct TrainingResponse: Codable {
    let id: String?
}

// MARK: - Occupancy query models (private)

private struct SlotOccupancyResponse: Codable {
    let data: [SlotOccupancyEntry]
}

private struct SlotOccupancyEntry: Codable {
    let slot: SlotIdOnly
    let times: [OccupancyTimeRef]
}

private struct SlotIdOnly: Codable {
    let id: Int
}

private struct OccupancyTimeRef: Codable {
    let gamingSpaceTimesId: OccupancyTimeId?
    enum CodingKeys: String, CodingKey {
        case gamingSpaceTimesId = "gaming_space_times_id"
    }
}

private struct OccupancyTimeId: Codable {
    let id: Int
}

class ReservationService {

    // MARK: - Crear reserve individual

    /// `POST gaming_space_reserves` with exactly the fields the gateway accepts
    /// (date, user, slot, team, training, times, companion_of). Status, QR and loans are set by the server.
    func createReservation(reservation: Reservation, companionOf: Int? = nil, completion: @escaping (Result<ReserveResponse, Error>) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var reservationDict: [String: Any] = [
            "slot": reservation.slot.id,
            "user": reservation.user ?? "",
            "date": dateFormatter.string(from: reservation.date),
            "times": reservation.times.map { ["gaming_space_times_id": ["id": $0.id]] },
        ]
        if let team = reservation.team { reservationDict["team"] = team }
        if let training = reservation.training { reservationDict["training"] = training }
        if let companionOf { reservationDict["companion_of"] = companionOf }

        Task {
            do {
                let reserveResponseModel: ReserveResponseModel = try await DirectusService.shared.sendRequest(
                    endpoint: "gaming_space_reserves",
                    method: .POST,
                    body: reservationDict
                )
                if reserveResponseModel.data.id != 0 {
                    Logger.shared.log("Reserva registrada con éxito")
                    completion(.success(reserveResponseModel.data))
                } else {
                    Logger.shared.log("Error: No se recibieron datos válidos.")
                    completion(.failure(NSError(domain: "com.example.error", code: 0, userInfo: [NSLocalizedDescriptionKey: "No se recibieron datos válidos."])))
                }
            } catch {
                Logger.shared.log("Error al hacer un registro: \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Crear training (con múltiples reserves)

    func createTraining(request: TrainingRequest, completion: @escaping (Result<TrainingResponse, Error>) -> Void) {
        let playersMapped = request.playerIds.map { ["users_id": $0] }
        let reservesMapped = request.reserveIds

        // The gateway sets the status; it only accepts team, notes, time, start_date, type, players, reserves.
        let body: [String: Any] = [
            "type":       request.type,
            "start_date": request.startDate,
            "time":       request.time,
            "team":       request.teamId,
            "notes":      request.notes,
            "players":    playersMapped,
            "reserves":   reservesMapped
        ]

        Task {
            do {
                let response: TrainingResponseModel = try await DirectusService.shared.sendRequest(
                    endpoint: "trainings",
                    method: .POST,
                    body: body
                )
                Logger.shared.log("Training creado con éxito")
                completion(.success(response.data))
            } catch {
                Logger.shared.log("Error al crear el training: \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Vincular reserves a un training

    func linkReservesToTraining(trainingId: String, reserveIds: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
        let body: [String: Any] = [
            "reserves": reserveIds
        ]

        Task {
            do {
                let _: TrainingResponseModel = try await DirectusService.shared.sendRequest(
                    endpoint: "trainings/\(trainingId)",
                    method: .PATCH,
                    body: body
                )
                Logger.shared.log("Reserves \(reserveIds) vinculadas a training \(trainingId)")
                completion(.success(()))
            } catch {
                Logger.shared.log("Error al vincular reserves al training: \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Actualizar training

    func updateTraining(
        trainingId: String,
        type: String,
        startDate: String,
        time: String,
        notes: String,
        playerIds: [String],
        completion: @escaping (Result<TrainingResponse, Error>) -> Void
    ) {
        let playersMapped = playerIds.map { ["users_id": $0] }

        let body: [String: Any] = [
            "type":       type,
            "start_date": startDate,
            "time":       time,
            "notes":      notes,
            "players":    playersMapped
        ]

        Task {
            do {
                let response: TrainingResponseModel = try await DirectusService.shared.sendRequest(
                    endpoint: "trainings/\(trainingId)",
                    method: .PATCH,
                    body: body
                )
                Logger.shared.log("Training actualizado con éxito")
                completion(.success(response.data))
            } catch {
                Logger.shared.log("Error al actualizar el training: \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Actualizar reserva existente (QR)

    func updateExistingReservation(reservationId: Int, qrImage: String, reservation: Reservation, completion: @escaping (Result<ReserveResponse, Error>) -> Void) {
        // The gateway only lets a member PATCH `qrImage` (or `status = cancelled`) on a reservation.
        let reservationDict: [String: Any] = ["qrImage": qrImage]

        let endpoint = "gaming_space_reserves/\(reservationId)"

        Task {
            do {
                let reserveResponseModel: ReserveResponseModel = try await DirectusService.shared.sendRequest(
                    endpoint: endpoint,
                    method: .PATCH,
                    body: reservationDict
                )

                if reserveResponseModel.data.id != 0 {
                    Logger.shared.log("Reserva actualizada con éxito")
                    completion(.success(reserveResponseModel.data))
                } else {
                    Logger.shared.log("Error: No se recibieron datos válidos.")
                    completion(.failure(NSError(domain: "com.example.error", code: 0, userInfo: [NSLocalizedDescriptionKey: "No se recibieron datos válidos."])))
                }
            } catch {
                Logger.shared.log("Error al actualizar la reserva: \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Flow IDs por entorno

    private var isPro: Bool {
        MIGEnvironment.current == .pro
    }

    private var individualReservationFlowId: String {
        isPro
            ? "4740cad9-f737-4eea-abf4-228b1d606e30"
            : "d0e0e727-d47f-48bd-92c9-85ba3046579f"
    }

    private var teamReservationFlowId: String {
        isPro
            ? "a9754b93-655a-488c-b43f-5501ae6c3b11"
            : "3a753e17-6004-461d-b548-ad3cebdb3111"
    }

    // MARK: - Emails de reserva (Directus Flows a través de la pasarela)

    /// The server builds and sends the email from the reservation record; the body is only `{"recordId": id}`.
    /// Failures are logged and never block the booking.
    func sendReservationEmail(reservationId: Int, isTeam: Bool = false) {
        let flowId = isTeam ? teamReservationFlowId : individualReservationFlowId
        Task {
            do {
                try await DirectusService.shared.triggerFlow(flowId: flowId, body: ["recordId": reservationId])
            } catch {
                Logger.shared.log("Error al enviar email de reserva: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Obtener trainings

    func getAllTrainings(teamId: String, userId: String, completion: @escaping (Result<[EventModel], Error>) -> Void) {
        let parameters: [String: String] = [
            "fields": "id, status, start_date, time, players.users_id.id, players.users_id.avatar, players.users_id.email, players.users_id.first_name, type, reserves.*, reserves.user, reserves.qrImage, reserves.qrValue, reserves.team.name, reserves.team.picture, reserves.times.gaming_space_times_id.time, notes",
            "filter[team][_eq]": teamId,
        ]

        Task {
            do {
                let response: EventModelResponse = try await DirectusService.shared.request(
                    endpoint: "trainings",
                    method: .GET,
                    parameters: parameters
                )
                completion(.success(response.data))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Obtener reserves individuales

    func getReservesByUser(userId: String, completion: @escaping (Result<[IndividualReservation], Error>) -> Void) {
        let parameters: [String: String] = [
            "fields": "id, date, slot.*, qrImage, qrValue, times.gaming_space_times_id.time, times.gaming_space_times_id.id, times.gaming_space_times_id.value",
            "filter[user][_eq]": userId,
            "filter[date][_gte]": "$NOW",
            "filter[training][_null]": "true",
            "sort[]": "date"
        ]

        Task {
            do {
                let response: IndividualReservationResponse = try await DirectusService.shared.request(
                    endpoint: "gaming_space_reserves",
                    method: .GET,
                    parameters: parameters
                )
                completion(.success(response.data))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Obtener gaming space por slot

    func getReservesSlotByUser(space: Int?, completion: @escaping (Result<[GamingSpace], Error>) -> Void) {
        let parameters: [String: String] = [
            "fields": "id, translations.*",
            "filter[id][_eq]": String(space ?? 0),
        ]

        Task {
            do {
                let response: GamingSpaceResponseData = try await DirectusService.shared.request(
                    endpoint: "gaming_space",
                    method: .GET,
                    parameters: parameters
                )
                completion(.success(response.data))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Ocupación de slots por espacio y fecha

    func getReservationsBySlots(slotIds: [Int], date: String, completion: @escaping (Result<[(slotId: Int, timeIds: [Int])], Error>) -> Void) {
        let slotIdsString = slotIds.map { String($0) }.joined(separator: ",")
        let parameters: [String: String] = [
            "fields": "slot.id,times.gaming_space_times_id.id",
            "filter[slot][_in]": slotIdsString,
            "filter[date][_eq]": date,
            "limit": "-1"
        ]

        Task {
            do {
                let response: SlotOccupancyResponse = try await DirectusService.shared.request(
                    endpoint: "gaming_space_reserves",
                    method: .GET,
                    parameters: parameters
                )
                let mapped = response.data.map { entry -> (slotId: Int, timeIds: [Int]) in
                    let timeIds = entry.times.compactMap { $0.gamingSpaceTimesId?.id }
                    return (slotId: entry.slot.id, timeIds: timeIds)
                }
                completion(.success(mapped))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Días bloqueados

    func getAllBlockedDays(completion: @escaping (Result<[BlockedDaysModel], Error>) -> Void) {
        let parameters: [String: String] = [
            "fields": "id, date, description",
            "filter[date][_gte]": Date().toServerDateString()
        ]

        Task {
            do {
                let response: BlockedDaysModelResponse = try await DirectusService.shared.request(
                    endpoint: "gaming_space_blocked_days",
                    method: .GET,
                    parameters: parameters
                )
                completion(.success(response.data))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func updateTrainingPlayers(
        trainingId: String,
        playerIds: [String],
        completion: @escaping (Result<TrainingResponse, Error>) -> Void
    ) {
        let playersMapped = playerIds.map { ["users_id": $0] }
        let body: [String: Any] = ["players": playersMapped]

        Task {
            do {
                let response: TrainingResponseModel = try await DirectusService.shared.sendRequest(
                    endpoint: "trainings/\(trainingId)",
                    method: .PATCH,
                    body: body
                )
                completion(.success(response.data))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Eliminar reserve

    func deleteReservation(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await DirectusService.shared.sendRequestWithoutDecode(
                    endpoint: "gaming_space_reserves/\(id)",
                    method: .DELETE,
                    body: [:]
                )
                completion(.success(()))
            } catch {
                Logger.shared.log("Error al eliminar la reserva: \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Eliminar training (y sus reserves si es centre)

    func deleteTraining(
        trainingId: String,
        reserveIds: [Int],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await DirectusService.shared.sendRequestWithoutDecode(
                    endpoint: "trainings/\(trainingId)",
                    method: .DELETE,
                    body: [:]
                )

                for reserveId in reserveIds {
                    try await DirectusService.shared.sendRequestWithoutDecode(
                        endpoint: "gaming_space_reserves/\(reserveId)",
                        method: .DELETE,
                        body: [:]
                    )
                }

                completion(.success(()))
            } catch {
                Logger.shared.log("Error al eliminar el training: \(error)")
                completion(.failure(error))
            }
        }
    }
}
