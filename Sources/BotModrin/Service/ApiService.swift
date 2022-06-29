import Foundation

#if os(Linux)
import FoundationNetworking
#endif

enum HttpError: Error {
    case code(Int)
    case unknow
}

class ApiService {
    
    static let modrinth = ApiService(urlString: "https://api.modrinth.com/v2")
    
    let urlString: String
    
    
    init(urlString: String) {
        self.urlString = urlString
    }
    
    func fetchApi<T: Codable>(_ endPointString: String, objectType: T.Type) async -> Result<T, Error> {
        
        let url = URL(string: urlString + endPointString)!
        
        var (data, response): (Data?, URLResponse?)
        
        
        do {
            #if os(Linux)
            (data, response) = try await withCheckedContinuation { continuation in
                URLSession.shared.dataTask(with: url) { data, response, _ in
                    continuation.resume(returning: (data, response))
                }.resume()
            }
            #else
            (data, response) = try await URLSession.shared.data(from: url)
            #endif
        } catch {
            return .failure(error)
        }
        
        guard let data = data, let response = response else {
            return .failure(HttpError.unknow)
        }
        
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        guard code == 200 else {
            return .failure(HttpError.code(code))
        }
        
        let decoder = JSONDecoder()
        
        do {
            let result = try decoder.decode(objectType, from: data)
            return .success(result)
        } catch(let error) {
            return .failure(error)
        }
        
    }
}
