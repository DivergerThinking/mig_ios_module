import XCTest
@testable import MadridInGameiOSModule

final class GatewayWritePolicyTests: XCTestCase {
    private func keys(_ collection: String, _ method: String, _ body: [String: Any]) -> Set<String> {
        Set(GatewayWritePolicy.sanitize(collection: collection, method: method, body: body).body.keys)
    }

    func testReservationCreateKeepsOnlyAcceptedFields() {
        let body: [String: Any] = ["status": "active", "slot": 15, "date": "2026-12-10", "user": "u",
                                   "peripheral_loans": [Int](), "times": [["gaming_space_times_id": ["id": 13]]], "companion_of": 7]
        XCTAssertEqual(keys("gaming_space_reserves", "POST", body), ["slot", "date", "user", "times", "companion_of"])
    }

    func testReservationPatchOnlyCarriesQrOrCancellation() {
        XCTAssertEqual(keys("gaming_space_reserves", "PATCH", ["qrImage": "f", "times": [Int](), "status": "active"]), ["qrImage"])
        XCTAssertEqual(keys("gaming_space_reserves", "PATCH", ["status": "cancelled"]), ["status"])
    }

    func testTrainingAndInscriptionDropStatus() {
        XCTAssertEqual(keys("trainings", "POST", ["status": "active", "type": "virtual", "team": "t", "players": [[String: String]]()]),
                       ["type", "team", "players"])
        XCTAssertEqual(keys("tournament_inscriptions", "POST", ["alias": "a", "status": "published", "id_user": "u"]), ["alias", "id_user"])
    }

    func testProfilePatchKeepsDniAndAvatar() {
        XCTAssertEqual(keys("users", "PATCH", ["dni": "00000000T", "email": "test@example.com", "avatar": "f"]), ["dni", "avatar"])
    }

    func testRemovedFieldNamesAreReported() {
        let result = GatewayWritePolicy.sanitize(collection: "trainings", method: "POST", body: ["status": "active", "type": "virtual"])
        XCTAssertEqual(result.removed, ["status"])
    }

    func testUnknownCollectionsAndReadsAreUntouched() {
        XCTAssertEqual(keys("team_news", "POST", ["x": 1]), ["x"])
        XCTAssertEqual(keys("trainings", "GET", ["anything": 1]), ["anything"])
    }

    func testCollectionFromEndpoint() {
        XCTAssertEqual(GatewayWritePolicy.collection(ofEndpoint: "gaming_space_reserves/7936"), "gaming_space_reserves")
        XCTAssertEqual(GatewayWritePolicy.collection(ofEndpoint: "users?fields=id"), "users")
    }

    func testReserveResponseDecodesTheGatewayPayload() throws {
        let json = #"{"data":{"id":7936,"date":"2026-12-10","user":"u","team":null,"training":null,"slot":15,"status":"active","qrValue":"q","qrImage":null,"times":[{"gaming_space_times_id":13}]}}"#
        let decoded = try JSONDecoder().decode(ReserveResponseModel.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.data.id, 7936)
        XCTAssertEqual(decoded.data.qrValue, "q")
    }
}

final class UploadResponseTests: XCTestCase {
    func testFileUploadResponseFromTheGatewayDecodes() throws {
        let json = #"{"data":{"id":"0a8e3834-77b1-4e67-821c-a5bbe1ad6449","type":"image/jpeg","filename_download":"test-qr.jpeg","width":64,"height":64,"filesize":"1825"}}"#
        let decoded = try JSONDecoder().decode(SendImageResponse.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.data.id, "0a8e3834-77b1-4e67-821c-a5bbe1ad6449")
    }
}
