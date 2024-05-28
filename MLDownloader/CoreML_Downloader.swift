import CoreML
import CryptoKit

@available(iOS 15.0.0, *)
@available(macOS 12.0, *)
public struct CoreMLDownloader {
    var latestEndpoint: URL
    var downloadEndpoint: URL
    var token: String
    var modelName: String
    let fileManager = FileManager.default
    var modelUrl: URL
    var compiledUrl: URL
    
    public init(
        latestEndpoint: URL,
        downloadEndpoint: URL,
        token: String,
        modelName: String = "model"
    ) {
        self.latestEndpoint = latestEndpoint
        self.downloadEndpoint = downloadEndpoint
        self.token = token
        self.modelName = modelName
        self.modelUrl = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("models/model.mlmodel")
        self.compiledUrl = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("models/model.mlmodelc")
    }
    
    public init(
        endpoint: URL,
        token: String,
        modelName: String = "model"
    ) {
        self.latestEndpoint = endpoint.appendingPathComponent("latest")
        self.downloadEndpoint = endpoint.appendingPathComponent("download")
        self.token = token
        self.modelName = modelName
        self.modelUrl = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("models/\(modelName).mlmodel")
        self.compiledUrl = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("models/\(modelName).mlmodelc")
    }
    public mutating func DownloadAndCompileModel() async throws -> MLModel {
        do {
            if fileManager.fileExists(atPath: modelUrl.path) {
                var origFileMD5 = CryptoKit.Insecure.MD5()
                
                origFileMD5.update(data: try Data(contentsOf: modelUrl))
                
                print("updating model...")
                
                // If the latest model and the current model's hash values are no the same, replace the current model with the latest model
                if try await fetchLatestMD5() != origFileMD5.finalize().description.dropFirst(12) {
                    try await self.downloadModel()
                } else {
                    print("model already at the latest version!")
                }
            // If there is no model, download the latest model version anyways
            } else {
                
                try fileManager.createDirectory(atPath: modelUrl.deletingLastPathComponent().path, withIntermediateDirectories: true)
                
                print("retrieving model...")
                try await self.downloadModel()
            }

            return try await self.RetrieveModel()
        } catch {
            throw error
        }
    }
    public mutating func RetrieveModel() async throws -> MLModel {
        do {
            if fileManager.fileExists(atPath: compiledUrl.path) {
                return try MLModel(contentsOf: compiledUrl)
            } else {
                compiledUrl = try await MLModel.compileModel(at: modelUrl) // Compiles the model file (goes from .mlmodel to .mlmodelc)
                return try MLModel(contentsOf: compiledUrl)
            }
        } catch {
            print("error while retrieving model: \(error)")
            throw error
        }
    }
    
    func fetchLatestMD5() async throws -> String {
        do {
            var request = URLRequest(url: latestEndpoint)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            // Get latest model's hash
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let decodedData = try decoder.decode(ModelDigest.self, from: data)
            
            return decodedData.md5
        } catch {
            print("an error occured while fetching latest model md5 hash: \(error)")
            throw error
        }
    }
    
    func downloadModel() async throws {
        
        print("downloading latest model...")
        do {
            var request = URLRequest(url: downloadEndpoint)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (tempUrl, _) = try await URLSession.shared.download(for: request) // Download the model from wherever it is stored
            
            let modelData = try Data(contentsOf: tempUrl) // Get the raw data
            
            print("a")
            
            try modelData.write(to: modelUrl) // Write new model file
            
            print("done!")
        } catch {
            print("an error occured while downloading: \(error)")
            throw error
        }
    }
}

public struct ModelDigest: Decodable {
    public let md5: String
    public let status: String
}
