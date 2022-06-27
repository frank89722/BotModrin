import Foundation

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
    
    func fetchApi<T: Codable>(_ endPointString: String, objectType: T.Type, completion: @escaping (Result<T, Error>) -> Void) {

        let url = URL(string: urlString + endPointString)!

        URLSession.shared.dataTask(with: url) { data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard code == 200 else {
                completion(.failure(HttpError.code(code)))
                return
            }

            guard let data = data else {
                completion(.failure(HttpError.unknow))
                return
            }

            let decoder = JSONDecoder()
            do {
                let result = try decoder.decode(objectType, from: data)
                completion(.success(result))
            } catch(let error) {
                completion(.failure(error))
            }

        }

    }
    
    func fetchApi<T: Codable>(_ endPointString: String, objectType: T.Type) async -> Result<T, Error> {
        
        let url = URL(string: urlString + endPointString)!
        let (data, response) = try! await URLSession.shared.data(from: url)
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
