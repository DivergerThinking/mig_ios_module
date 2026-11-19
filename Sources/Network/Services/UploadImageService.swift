//
//  UploadImageService.swift
//  Pods
//
//  Created by Arnau Rivas Rivas on 25/2/25.
//


import UIKit

class UploadImageService {
    
    let environmentManager = EnvironmentManager()

    func uploadImage(image: UIImage, fileName: String, compressionQuality: CGFloat = 0.5, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(environmentManager.getBaseURL())/files") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            completion(.failure(NetworkError.encodingError))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        Task {
            let result: Result<String, Error>
            do {
                let (data, response) = try await MIGHTTPClient.shared.send(request)
                if (200..<300).contains(response.statusCode), let text = String(data: data, encoding: .utf8) {
                    result = .success(text)
                } else {
                    result = .failure(NetworkError.serverError(statusCode: response.statusCode))
                }
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

}
