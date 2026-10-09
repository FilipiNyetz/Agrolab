//
//  APIClient.swift
//  Agrolab
//

import Foundation

// MARK: - Erros

/// Corpo padrão de erro da API: `{"error":{"code":..., "message":..., "request_id":...}}`
nonisolated struct ServerProblem: Decodable, Sendable, Equatable {
    let code: String
    let message: String
    let requestID: String?

    enum CodingKeys: String, CodingKey {
        case code, message
        case requestID = "request_id"
    }
}

nonisolated struct ErrorEnvelope: Decodable, Sendable {
    let error: ServerProblem
}

nonisolated enum APIError: Error, Sendable {
    case invalidResponse
    case encoding
    case decoding(String)
    case network(URLError)
    case server(status: Int, problem: ServerProblem?, retryAfter: TimeInterval?)

    var status: Int? {
        if case .server(let status, _, _) = self { return status }
        return nil
    }

    var code: String? {
        if case .server(_, let problem, _) = self { return problem?.code }
        return nil
    }

    var retryAfter: TimeInterval? {
        if case .server(_, _, let retry) = self { return retry }
        return nil
    }

    var isUnauthorized: Bool { status == 401 }

    /// Erros que indicam que a sessão/token não serve mais (não vale a pena tentar de novo).
    var isSessionRejected: Bool {
        guard let status else { return false }
        return [400, 401, 422].contains(status)
    }

    var isConnectivityIssue: Bool {
        if case .network = self { return true }
        return false
    }

    /// Mensagem pronta para exibir ao usuário, em pt-BR.
    var userMessage: String {
        switch self {
        case .invalidResponse, .encoding:
            return "Resposta inesperada do servidor. Tente novamente."
        case .decoding:
            return "Não foi possível interpretar a resposta do servidor."
        case .network(let error):
            switch error.code {
            case .timedOut:
                return "A conexão demorou demais. Verifique sua internet e tente novamente."
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .cannotFindHost, .cannotConnectToHost, .internationalRoamingOff:
                return "Sem conexão com a internet. Verifique sua rede e tente novamente."
            default:
                return "Falha de conexão. Tente novamente."
            }
        case .server(let status, let problem, let retryAfter):
            switch status {
            case 429:
                let seconds = Int((retryAfter ?? 60).rounded(.up))
                return "Muitas tentativas. Aguarde \(seconds) segundos e tente novamente."
            case 500...:
                return "O serviço está temporariamente indisponível. Tente novamente em instantes."
            default:
                return problem?.message ?? "Não foi possível concluir a solicitação (\(status))."
            }
        }
    }
}

nonisolated extension Error {
    /// Mensagem amigável para qualquer erro que chegue às telas.
    var agroMessage: String {
        if let apiError = self as? APIError { return apiError.userMessage }
        if let localized = self as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return "Algo deu errado. Tente novamente."
    }
}

// MARK: - Requisição

nonisolated struct APIRequest: Sendable {
    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case delete = "DELETE"
    }

    var method: Method
    var path: String
    var body: (any Encodable & Sendable)?
    var accessToken: String?

    init(_ method: Method, _ path: String, body: (any Encodable & Sendable)? = nil, accessToken: String? = nil) {
        self.method = method
        self.path = path
        self.body = body
        self.accessToken = accessToken
    }
}

// MARK: - Cliente

/// Cliente HTTP mínimo baseado em URLSession: JSON, headers, status HTTP, erros e timeout.
nonisolated struct APIClient: Sendable {
    let baseURL: URL
    let timeout: TimeInterval
    let urlSession: URLSession

    init(baseURL: URL, timeout: TimeInterval = 20, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.urlSession = urlSession
    }

    /// Envia a requisição e decodifica o JSON de resposta.
    func send<Response: Decodable & Sendable>(_ request: APIRequest) async throws -> Response {
        let (data, _) = try await perform(request)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// Envia a requisição ignorando o corpo da resposta (ex.: 204 No Content).
    func send(_ request: APIRequest) async throws {
        _ = try await perform(request)
    }

    private func perform(_ request: APIRequest) async throws -> (Data, HTTPURLResponse) {
        let url = baseURL.appending(path: request.path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = timeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = request.body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                urlRequest.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw APIError.encoding
            }
        }

        if let token = request.accessToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: urlRequest)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw APIError.network(error)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.network(URLError(.unknown))
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let problem = try? JSONDecoder().decode(ErrorEnvelope.self, from: data).error
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
            throw APIError.server(status: http.statusCode, problem: problem, retryAfter: retryAfter)
        }

        return (data, http)
    }
}
