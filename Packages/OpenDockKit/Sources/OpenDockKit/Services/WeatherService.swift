import Foundation

public struct WeatherPlace: Codable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let country: String?
    public let admin1: String?
    public var label: String { [name, admin1, country].compactMap { $0 }.joined(separator: ", ") }
}

public struct WeatherSnapshot: Codable, Sendable {
    public let temperature: Double
    public let feelsLike: Double
    public let high: Double
    public let low: Double
    public let code: Int
    public let isDay: Bool
    public let fetchedAt: Date

    public var condition: String {
        switch code {
        case 0: "Clear"
        case 1, 2: "Partly cloudy"
        case 3: "Overcast"
        case 45, 48: "Fog"
        case 51...57: "Drizzle"
        case 61...67, 80...82: "Rain"
        case 71...77, 85, 86: "Snow"
        case 95...99: "Thunderstorms"
        default: "Conditions unavailable"
        }
    }
    public var symbol: String {
        switch code {
        case 0: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57: "cloud.drizzle.fill"
        case 61...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud"
        }
    }
}

/// Open-Meteo endpoints are fixed here; widgets never perform network access directly.
public struct WeatherService {
    public init() {}
    public func search(_ query: String) async throws -> [WeatherPlace] {
        var url = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        url.queryItems = [URLQueryItem(name: "name", value: query), .init(name: "count", value: "5"), .init(name: "language", value: "en")]
        struct Results: Decodable { let results: [WeatherPlace]? }
        return try await load(Results.self, url: url.url!).results ?? []
    }
    public func forecast(for place: WeatherPlace) async throws -> WeatherSnapshot {
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            .init(name: "latitude", value: String(place.latitude)), .init(name: "longitude", value: String(place.longitude)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            .init(name: "timezone", value: "auto"), .init(name: "forecast_days", value: "1")
        ]
        struct Response: Decodable {
            struct Current: Decodable { let temperature_2m: Double; let apparent_temperature: Double; let weather_code: Int; let is_day: Int }
            struct Daily: Decodable { let temperature_2m_max: [Double]; let temperature_2m_min: [Double] }
            let current: Current
            let daily: Daily
        }
        let response = try await load(Response.self, url: url.url!)
        guard let high = response.daily.temperature_2m_max.first, let low = response.daily.temperature_2m_min.first else {
            throw URLError(.cannotParseResponse)
        }
        return WeatherSnapshot(temperature: response.current.temperature_2m, feelsLike: response.current.apparent_temperature,
            high: high, low: low, code: response.current.weather_code, isDay: response.current.is_day == 1, fetchedAt: .now)
    }
    private func load<T: Decodable>(_ type: T.Type, url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 15))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        try Task.checkCancellation()
        return try JSONDecoder().decode(type, from: data)
    }
}
