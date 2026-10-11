import Foundation
import Observation

@MainActor
@Observable
final class WeatherService {
    private let cityKey = "weatherCity"
    private let latKey = "weatherLatitude"
    private let lonKey = "weatherLongitude"
    private let placeKey = "weatherPlaceName"

    var city: String
    var placeName: String?
    var temperature: Double?
    var weatherCode: Int?
    var lastUpdated: Date?
    var errorText: String?

    init() {
        if let savedCity = UserDefaults.standard.string(forKey: cityKey), !savedCity.isEmpty {
            self.city = savedCity
        } else {
            let tz = TimeZone.current.identifier
            let rawCity = tz.components(separatedBy: "/").last ?? "Jakarta"
            self.city = rawCity.replacingOccurrences(of: "_", with: " ")
        }
        self.placeName = UserDefaults.standard.string(forKey: placeKey)
    }

    func setCity(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        city = trimmed
        UserDefaults.standard.set(trimmed, forKey: cityKey)
        UserDefaults.standard.removeObject(forKey: latKey)
        UserDefaults.standard.removeObject(forKey: lonKey)
        UserDefaults.standard.removeObject(forKey: placeKey)
        placeName = nil
        lastUpdated = nil
        errorText = nil
        refresh()
    }

    func refreshIfStale() {
        if let last = lastUpdated, Date().timeIntervalSince(last) < 1800 {
            return
        }
        refresh()
    }

    func refresh() {
        Task { [weak self] in
            await self?.fetchWeather()
        }
    }

    private func fetchWeather() async {
        let currentCity = city
        var lat = UserDefaults.standard.double(forKey: latKey)
        var lon = UserDefaults.standard.double(forKey: lonKey)
        var place = UserDefaults.standard.string(forKey: placeKey)

        if lat == 0 && lon == 0 {
            var comp = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
            comp?.queryItems = [
                URLQueryItem(name: "name", value: currentCity),
                URLQueryItem(name: "count", value: "1")
            ]
            guard let url = comp?.url else {
                errorText = "Invalid city name"
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                struct GeoResult: Decodable {
                    let name: String
                    let latitude: Double
                    let longitude: Double
                    let country: String?
                }
                struct GeoResponse: Decodable {
                    let results: [GeoResult]?
                }

                let geo = try JSONDecoder().decode(GeoResponse.self, from: data)
                guard let first = geo.results?.first else {
                    errorText = "City not found"
                    return
                }

                lat = first.latitude
                lon = first.longitude
                place = first.name
                UserDefaults.standard.set(lat, forKey: latKey)
                UserDefaults.standard.set(lon, forKey: lonKey)
                UserDefaults.standard.set(place, forKey: placeKey)
            } catch {
                errorText = "Weather unavailable"
                return
            }
        }

        var forecastComp = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        forecastComp?.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code")
        ]
        guard let forecastUrl = forecastComp?.url else {
            errorText = "Weather unavailable"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: forecastUrl)
            struct CurrentWeather: Decodable {
                let temperature_2m: Double
                let weather_code: Int
            }
            struct ForecastResponse: Decodable {
                let current: CurrentWeather
            }

            let forecast = try JSONDecoder().decode(ForecastResponse.self, from: data)
            self.temperature = forecast.current.temperature_2m
            self.weatherCode = forecast.current.weather_code
            self.placeName = place ?? currentCity
            self.lastUpdated = Date()
            self.errorText = nil
        } catch {
            errorText = "Weather unavailable"
        }
    }

    var symbolName: String {
        guard let code = weatherCode else { return "cloud.fill" }
        switch code {
        case 0:
            return "sun.max.fill"
        case 1, 2, 3:
            return "cloud.sun.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51...57:
            return "cloud.drizzle.fill"
        case 61...67, 80...82:
            return "cloud.rain.fill"
        case 71...77, 85, 86:
            return "cloud.snow.fill"
        case 95...99:
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.fill"
        }
    }

    var summary: String {
        guard let code = weatherCode else { return "Unknown" }
        switch code {
        case 0:
            return "Clear"
        case 1, 2, 3:
            return "Partly Cloudy"
        case 45, 48:
            return "Fog"
        case 51...57:
            return "Drizzle"
        case 61...67, 80...82:
            return "Rain"
        case 71...77, 85, 86:
            return "Snow"
        case 95...99:
            return "Thunderstorm"
        default:
            return "Overcast"
        }
    }
}
