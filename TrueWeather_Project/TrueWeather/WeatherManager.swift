import Foundation
import SwiftUI
import Combine

// Models
struct CurrentWeather {
    let city: String
    let temp: Int
    let desc: String
    let emoji: String
    let feelsLike: Int
    let windSpeed: Int
    let humidity: Int
    let rainChance: Int
    let uvIndex: Int
    let timeString: String
}

struct HourlyWeather: Identifiable {
    let id = UUID()
    let time: String
    let temp: Int
    let emoji: String
}

struct DailyWeather: Identifiable {
    let id = UUID()
    let dateLabel: String
    let tempMax: Int
    let tempMin: Int
    let emoji: String
}

struct FavoriteCity {
    let city: String
    let temp: Int
    let desc: String
    let emoji: String
    let time: String
}

class WeatherManager: ObservableObject {
    @AppStorage("temperatureUnit") private var temperatureUnit = "C"
    
    @Published var currentCity: String = "London"
    @Published var currentWeather: CurrentWeather?
    @Published var hourlyData: [HourlyWeather] = []
    @Published var dailyData: [DailyWeather] = []
    @Published var favorites: [FavoriteCity] = []
    
    // Autocomplete State
    @Published var searchSuggestions: [String] = []
    private var searchTask: DispatchWorkItem?
    
    private var favoriteNames: [String] = ["New York", "Tokyo", "London"]
    private var timeTimer: Timer?
    private var currentTimezone = "UTC"
    
    // Convert logic
    private func convertTemp(_ tempC: Double) -> Int {
        if temperatureUnit == "F" {
            return Int(round((tempC * 9/5) + 32))
        }
        return Int(round(tempC))
    }
    
    private func convertWind(_ speedKmh: Double) -> Int {
        if temperatureUnit == "F" {
            return Int(round(speedKmh * 0.621371)) // mph
        }
        return Int(round(speedKmh))
    }
    
    // Autocomplete Logic
    func fetchSuggestions(for query: String) {
        searchTask?.cancel()
        
        if query.count < 2 {
            DispatchQueue.main.async { self.searchSuggestions = [] }
            return
        }
        
        let task = DispatchWorkItem { [weak self] in
            let safeQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let urlStr = "https://geocoding-api.open-meteo.com/v1/search?name=\(safeQuery)&count=5&language=en&format=json"
            guard let url = URL(string: urlStr) else { return }
            
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data else { return }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let results = json["results"] as? [[String: Any]] {
                        
                        var suggestions: [String] = []
                        for loc in results {
                            if let name = loc["name"] as? String {
                                var display = name
                                if let admin = loc["admin1"] as? String { display += ", \(admin)" }
                                else if let country = loc["country"] as? String { display += ", \(country)" }
                                
                                if !suggestions.contains(display) {
                                    suggestions.append(display)
                                }
                            }
                        }
                        
                        DispatchQueue.main.async { self?.searchSuggestions = suggestions }
                    } else {
                        DispatchQueue.main.async { self?.searchSuggestions = [] }
                    }
                } catch { }
            }.resume()
        }
        
        searchTask = task
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3, execute: task)
    }
    
    // Main Weather Logic
    func fetchWeather(for city: String) {
        let safeCity = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        let geoUrlStr = "https://geocoding-api.open-meteo.com/v1/search?name=\(safeCity)&count=1&language=en&format=json"
        
        guard let geoUrl = URL(string: geoUrlStr) else { return }
        
        URLSession.shared.dataTask(with: geoUrl) { data, _, _ in
            guard let data = data else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let loc = results.first,
                   let lat = loc["latitude"] as? Double,
                   let lon = loc["longitude"] as? Double {
                    
                    let name = loc["name"] as? String ?? city
                    let tz = loc["timezone"] as? String ?? "UTC"
                    
                    self.fetchWeatherDetails(lat: lat, lon: lon, name: name, timezone: tz)
                }
            } catch {
                print("Error parsing geo data")
            }
        }.resume()
    }
    
    private func fetchWeatherDetails(lat: Double, lon: Double, name: String, timezone: String) {
        let weatherUrlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,apparent_temperature,wind_speed_10m,relative_humidity_2m,weather_code&hourly=temperature_2m,weather_code,precipitation_probability,uv_index&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=auto&forecast_days=14"
        
        guard let weatherUrl = URL(string: weatherUrlStr) else { return }
        
        URLSession.shared.dataTask(with: weatherUrl) { data, _, _ in
            guard let data = data else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    DispatchQueue.main.async {
                        self.parseAndSetWeather(name: name, tz: timezone, json: json)
                    }
                }
            } catch {
                print("Error parsing weather data")
            }
        }.resume()
    }
    
    private func parseAndSetWeather(name: String, tz: String, json: [String: Any]) {
        self.currentCity = name
        self.currentTimezone = tz
        
        guard let current = json["current"] as? [String: Any],
              let hourly = json["hourly"] as? [String: Any],
              let daily = json["daily"] as? [String: Any] else { return }
        
        let code = current["weather_code"] as? Int ?? 0
        let desc = getWeatherDesc(code)
        
        let rainChance = (hourly["precipitation_probability"] as? [Int])?.first ?? 0
        let uv = (hourly["uv_index"] as? [Double])?.first ?? 0
        
        self.currentWeather = CurrentWeather(
            city: name,
            temp: convertTemp(current["temperature_2m"] as? Double ?? 0),
            desc: desc,
            emoji: getEmoji(desc),
            feelsLike: convertTemp(current["apparent_temperature"] as? Double ?? 0),
            windSpeed: convertWind(current["wind_speed_10m"] as? Double ?? 0),
            humidity: current["relative_humidity_2m"] as? Int ?? 0,
            rainChance: rainChance,
            uvIndex: Int(round(uv)),
            timeString: "" 
        )
        
        var newHourly: [HourlyWeather] = []
        if let times = hourly["time"] as? [String],
           let temps = hourly["temperature_2m"] as? [Double],
           let codes = hourly["weather_code"] as? [Int] {
            for i in 0..<min(24, times.count) {
                let timeStr = times[i].components(separatedBy: "T").last ?? "00:00"
                let emoji = getEmoji(getWeatherDesc(codes[i]))
                newHourly.append(HourlyWeather(time: timeStr, temp: convertTemp(temps[i]), emoji: emoji))
            }
        }
        self.hourlyData = newHourly
        
        var newDaily: [DailyWeather] = []
        if let times = daily["time"] as? [String],
           let maxTemps = daily["temperature_2m_max"] as? [Double],
           let minTemps = daily["temperature_2m_min"] as? [Double],
           let codes = daily["weather_code"] as? [Int] {
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "EEEE, MMM d"
            
            for i in 0..<min(14, times.count) {
                let dateStr = times[i]
                var label = dateStr
                if i == 0 { label = "Today" } 
                else if let date = formatter.date(from: dateStr) { label = displayFormatter.string(from: date) }
                
                let emoji = getEmoji(getWeatherDesc(codes[i]))
                newDaily.append(DailyWeather(dateLabel: label, tempMax: convertTemp(maxTemps[i]), tempMin: convertTemp(minTemps[i]), emoji: emoji))
            }
        }
        self.dailyData = newDaily
        
        startTimer()
        fetchFavorites()
    }
    
    private func startTimer() {
        timeTimer?.invalidate()
        updateTime()
        timeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in self.updateTime() }
    }
    
    private func updateTime() {
        guard let tz = TimeZone(identifier: currentTimezone) else { return }
        let formatter = DateFormatter()
        formatter.timeZone = tz
        formatter.dateFormat = "EEEE, d MMMM  |  h:mm a"
        
        let timeStr = formatter.string(from: Date())
        
        if let cw = currentWeather {
            currentWeather = CurrentWeather(
                city: cw.city, temp: cw.temp, desc: cw.desc, emoji: cw.emoji,
                feelsLike: cw.feelsLike, windSpeed: cw.windSpeed, humidity: cw.humidity,
                rainChance: cw.rainChance, uvIndex: cw.uvIndex, timeString: timeStr
            )
        }
    }
    
    func toggleFavorite() {
        if favoriteNames.contains(currentCity) { favoriteNames.removeAll { $0 == currentCity } } 
        else { favoriteNames.append(currentCity) }
        fetchFavorites()
    }
    
    func isFavorite(city: String) -> Bool { return favoriteNames.contains(city) }
    
    private func fetchFavorites() {
        var fetchedFavs: [FavoriteCity] = []
        let group = DispatchGroup()
        
        for city in favoriteNames {
            group.enter()
            let safeCity = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
            let geoUrlStr = "https://geocoding-api.open-meteo.com/v1/search?name=\(safeCity)&count=1&language=en&format=json"
            guard let geoUrl = URL(string: geoUrlStr) else { group.leave(); continue }
            
            URLSession.shared.dataTask(with: geoUrl) { data, _, _ in
                defer { group.leave() }
                guard let data = data else { return }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let results = json["results"] as? [[String: Any]],
                       let loc = results.first,
                       let lat = loc["latitude"] as? Double,
                       let lon = loc["longitude"] as? Double {
                        
                        let tzStr = loc["timezone"] as? String ?? "UTC"
                        let name = loc["name"] as? String ?? city
                        
                        let weatherUrlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code"
                        if let wUrl = URL(string: weatherUrlStr),
                           let wData = try? Data(contentsOf: wUrl),
                           let wJson = try? JSONSerialization.jsonObject(with: wData, options: []) as? [String: Any],
                           let current = wJson["current"] as? [String: Any] {
                            
                            let tempC = current["temperature_2m"] as? Double ?? 0
                            let temp = self.convertTemp(tempC)
                            let code = current["weather_code"] as? Int ?? 0
                            let desc = self.getWeatherDesc(code)
                            let emoji = self.getEmoji(desc)
                            
                            var timeStr = "--:--"
                            if let tz = TimeZone(identifier: tzStr) {
                                let formatter = DateFormatter()
                                formatter.timeZone = tz
                                formatter.dateFormat = "h:mm a"
                                timeStr = formatter.string(from: Date())
                            }
                            
                            fetchedFavs.append(FavoriteCity(city: name, temp: temp, desc: desc, emoji: emoji, time: timeStr))
                        }
                    }
                } catch { }
            }.resume()
        }
        
        group.notify(queue: .main) { self.favorites = fetchedFavs }
    }
    
    private func getWeatherDesc(_ code: Int) -> String {
        switch code {
        case 0: return "Clear Sky"
        case 1: return "Mainly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53: return "Light Drizzle"
        case 61, 63: return "Rain"
        case 65: return "Heavy Rain"
        case 71, 73: return "Snow"
        case 95...99: return "Thunderstorms"
        default:
            if code > 50 && code < 70 { return "Rain" }
            if code >= 70 && code < 80 { return "Snow" }
            return "Clear Sky"
        }
    }
    
    private func getEmoji(_ desc: String) -> String {
        let d = desc.lowercased()
        if d.contains("clear") { return "☀️" }
        if d.contains("cloud") || d.contains("overcast") { return "☁️" }
        if d.contains("rain") || d.contains("drizzle") { return "🌧️" }
        if d.contains("snow") { return "❄️" }
        if d.contains("thunder") { return "⚡" }
        if d.contains("fog") { return "🌫️" }
        return "☀️"
    }
}