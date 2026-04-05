import SwiftUI

// MARK: - App Colors (High-End Dark Theme)
struct AppColors {
    static let background = Color(hex: "0B0B0B")
    static let card = Color(hex: "1C1C1E")
    static let border = Color(hex: "2C2C2E")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "EBEBF5")
    static let textTertiary = Color(hex: "8E8E93")
    static let accentYellow = Color(hex: "F9D423")
    static let accentBlue = Color(hex: "0A84FF")
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Main ContentView
struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var weatherManager = WeatherManager()
    @State private var searchText = ""
    @State private var showingTrends = false
    
    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView()
        } else {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        // Main Content Scroll
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 25) {
                                HeroSection(weather: weatherManager.currentWeather, isFavorite: weatherManager.isFavorite(city: weatherManager.currentCity)) {
                                    weatherManager.toggleFavorite()
                                }
                                
                                AirQualityGrid(weather: weatherManager.currentWeather)
                                
                                HourlyRow(hourlyData: weatherManager.hourlyData)
                                
                                FavoritesList(favorites: weatherManager.favorites) { city in
                                    weatherManager.fetchWeather(for: city)
                                }
                                
                                Color.clear.frame(height: 100)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 90) // Push content down so SearchBar doesn't overlap it
                        }
                        
                        // Floating Search Bar & Dropdown
                        VStack(spacing: 0) {
                            SearchBar(text: $searchText, onCommit: {
                                if !searchText.isEmpty {
                                    weatherManager.fetchWeather(for: searchText)
                                    searchText = ""
                                    weatherManager.searchSuggestions = []
                                }
                            }, onChange: { query in
                                weatherManager.fetchSuggestions(for: query)
                            })
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                            .background(AppColors.background) // Hide scrolling content behind it
                            
                            // Suggestions Dropdown
                            if !weatherManager.searchSuggestions.isEmpty && !searchText.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(weatherManager.searchSuggestions, id: \.self) { suggestion in
                                        Button(action: {
                                            let cleanCity = suggestion.components(separatedBy: ",").first ?? suggestion
                                            weatherManager.fetchWeather(for: cleanCity)
                                            searchText = ""
                                            weatherManager.searchSuggestions = []
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        }) {
                                            Text(suggestion)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(AppColors.textPrimary)
                                                .padding(.vertical, 15)
                                                .padding(.horizontal, 20)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        if suggestion != weatherManager.searchSuggestions.last {
                                            Divider().background(AppColors.border)
                                        }
                                    }
                                }
                                .background(AppColors.card)
                                .cornerRadius(15)
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(AppColors.border, lineWidth: 1))
                                .padding(.horizontal, 20)
                                .shadow(color: .black.opacity(0.5), radius: 15, y: 10)
                            }
                        }
                        .zIndex(10) // Ensure search dropdown floats above EVERYTHING
                    }
                }
                
                // Bottom Sheet Pill Button
                VStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showingTrends = true
                        }
                    }) {
                        HStack(spacing: 10) {
                            Text("📈").font(.system(size: 20))
                            Text("14-Day Trends")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 25)
                        .background(Color(white: 0.15).opacity(0.85))
                        .cornerRadius(40)
                        .overlay(RoundedRectangle(cornerRadius: 40).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                    }
                    .padding(.bottom, 30)
                }
                
                if showingTrends {
                    TrendsModal(
                        isShowing: $showingTrends,
                        city: weatherManager.currentCity,
                        dailyData: weatherManager.dailyData
                    )
                    .transition(.move(edge: .bottom))
                    .zIndex(20) 
                }
            }
            .onAppear {
                weatherManager.fetchWeather(for: "London")
            }
        }
    }
}

// MARK: - ONBOARDING VIEW
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("temperatureUnit") private var temperatureUnit = "C"
    @State private var currentStep = 0 
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack {
                if currentStep == 0 {
                    Spacer()
                    VStack(spacing: 20) {
                        Text("☁️⚡").font(.system(size: 100)).padding(.bottom, 20)
                        Text("Welcome to").font(.system(size: 24, weight: .medium)).foregroundColor(AppColors.textSecondary)
                        Text("TrueWeather").font(.system(size: 42, weight: .bold, design: .rounded)).foregroundColor(AppColors.textPrimary)
                        Text("High-end weather tracking. Accurate forecasts. Beautiful design.")
                            .font(.system(size: 16)).foregroundColor(AppColors.textTertiary).multilineTextAlignment(.center).padding(.horizontal, 40).padding(.top, 10)
                    }
                    Spacer()
                    Button(action: { withAnimation { currentStep = 1 } }) {
                        Text("Get Started").font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.background)
                            .frame(maxWidth: .infinity).padding(.vertical, 18).background(AppColors.textPrimary).cornerRadius(15)
                    }.padding(.horizontal, 30).padding(.bottom, 50)
                    
                } else if currentStep == 1 {
                    Spacer()
                    VStack(spacing: 30) {
                        Text("🌡️").font(.system(size: 80)).padding(.bottom, 10)
                        Text("Choose Your Unit").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundColor(AppColors.textPrimary)
                        Text("How do you prefer to view temperature?").font(.system(size: 16)).foregroundColor(AppColors.textTertiary).padding(.bottom, 20)
                        
                        HStack(spacing: 20) {
                            Button(action: { temperatureUnit = "C" }) {
                                VStack(spacing: 15) {
                                    Text("°C").font(.system(size: 40, weight: .bold))
                                    Text("Celsius").font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(temperatureUnit == "C" ? AppColors.background : AppColors.textPrimary)
                                .frame(maxWidth: .infinity).padding(.vertical, 30).background(temperatureUnit == "C" ? AppColors.textPrimary : AppColors.card).cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(temperatureUnit == "C" ? Color.clear : AppColors.border, lineWidth: 2))
                            }
                            
                            Button(action: { temperatureUnit = "F" }) {
                                VStack(spacing: 15) {
                                    Text("°F").font(.system(size: 40, weight: .bold))
                                    Text("Fahrenheit").font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(temperatureUnit == "F" ? AppColors.background : AppColors.textPrimary)
                                .frame(maxWidth: .infinity).padding(.vertical, 30).background(temperatureUnit == "F" ? AppColors.textPrimary : AppColors.card).cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(temperatureUnit == "F" ? Color.clear : AppColors.border, lineWidth: 2))
                            }
                        }.padding(.horizontal, 30)
                    }
                    Spacer()
                    Button(action: { withAnimation { hasCompletedOnboarding = true } }) {
                        Text("Continue").font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.background)
                            .frame(maxWidth: .infinity).padding(.vertical, 18).background(AppColors.textPrimary).cornerRadius(15)
                    }.padding(.horizontal, 30).padding(.bottom, 50)
                }
            }
        }
    }
}

// MARK: - UI Components
struct SearchBar: View {
    @Binding var text: String
    var onCommit: () -> Void
    var onChange: (String) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(AppColors.textTertiary)
            TextField("Search for a city...", text: $text, onEditingChanged: { _ in }, onCommit: onCommit)
                .foregroundColor(AppColors.textPrimary).accentColor(AppColors.accentBlue)
                .onChange(of: text) { newValue in onChange(newValue) }
        }
        .padding(.vertical, 12).padding(.horizontal, 15)
        .background(AppColors.card).cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(AppColors.border, lineWidth: 1))
    }
}

struct HeroSection: View {
    @AppStorage("temperatureUnit") private var unit = "C"
    let weather: CurrentWeather?
    let isFavorite: Bool
    let toggleFavorite: () -> Void
    
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text("📍").foregroundColor(AppColors.accentYellow)
                Text(weather?.city ?? "Loading...").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundColor(AppColors.textPrimary)
                Spacer()
                Button(action: toggleFavorite) { Text(isFavorite ? "❤️" : "🤍").font(.system(size: 24)) }
            }
            Text(weather?.timeString ?? "--:--").font(.system(size: 14, weight: .medium)).foregroundColor(AppColors.textTertiary)
            Text("\(weather?.temp ?? 0)°").font(.system(size: 110, weight: .light, design: .rounded)).foregroundColor(AppColors.textPrimary).tracking(-4).padding(.vertical, -10)
            HStack(spacing: 10) {
                Text(weather?.emoji ?? "☁️").font(.system(size: 28))
                Text(weather?.desc ?? "--").font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

struct AirQualityGrid: View {
    @AppStorage("temperatureUnit") private var unit = "C"
    let weather: CurrentWeather?
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                GridItem(icon: "🌡️", title: "REAL FEEL", value: "\(weather?.feelsLike ?? 0)°")
                GridItem(icon: "💨", title: "WIND", value: "\(weather?.windSpeed ?? 0) \(unit == "C" ? "km/h" : "mph")")
            }
            HStack(spacing: 20) {
                GridItem(icon: "💧", title: "RAIN CHANCE", value: "\(weather?.rainChance ?? 0)%")
                GridItem(icon: "☀️", title: "UV INDEX", value: "\(weather?.uvIndex ?? 0)")
            }
        }
        .padding(20).background(AppColors.card).cornerRadius(25)
    }
}

struct GridItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(icon).font(.system(size: 16))
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.textTertiary).tracking(0.5)
            }
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HourlyRow: View {
    let hourlyData: [HourlyWeather]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("🕒 24-HOUR FORECAST").font(.system(size: 12, weight: .bold)).foregroundColor(AppColors.textTertiary).tracking(1).padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(hourlyData, id: \.id) { hour in
                        VStack(spacing: 10) {
                            Text(hour.time).font(.system(size: 15, weight: .medium)).foregroundColor(AppColors.textPrimary)
                            Text(hour.emoji).font(.system(size: 26))
                            Text("\(hour.temp)°").font(.system(size: 20, weight: .bold)).foregroundColor(AppColors.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 20).background(AppColors.card).cornerRadius(25)
    }
}

struct FavoritesList: View {
    let favorites: [FavoriteCity]
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("⭐ SAVED LOCATIONS").font(.system(size: 12, weight: .bold)).foregroundColor(AppColors.textTertiary).tracking(1)
            
            if favorites.isEmpty {
                Text("No favorites added yet.").font(.system(size: 14)).foregroundColor(AppColors.textTertiary)
            } else {
                ForEach(favorites, id: \.city) { fav in
                    Button(action: { onSelect(fav.city) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(fav.city).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(AppColors.textPrimary)
                                Text(fav.time).font(.system(size: 14, weight: .medium)).foregroundColor(AppColors.textTertiary)
                            }
                            Spacer()
                            HStack(spacing: 15) {
                                Text(fav.emoji).font(.system(size: 32))
                                Text("\(fav.temp)°").font(.system(size: 42, weight: .regular, design: .rounded)).foregroundColor(AppColors.textPrimary)
                            }
                        }
                        .padding(20).background(AppColors.card).cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct TrendsModal: View {
    @Binding var isShowing: Bool
    let city: String
    let dailyData: [DailyWeather]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(city) Trends").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundColor(AppColors.textPrimary).tracking(-1)
                Spacer()
                Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isShowing = false } }) {
                    ZStack {
                        Circle().fill(AppColors.card).frame(width: 36, height: 36)
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .padding(.top, 60).padding(.horizontal, 20).padding(.bottom, 20).background(AppColors.background)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📊 TEMPERATURE GRAPH").font(.system(size: 12, weight: .bold)).foregroundColor(AppColors.textTertiary).tracking(1)
                        ZStack {
                            RoundedRectangle(cornerRadius: 25).fill(AppColors.card).frame(height: 200)
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 150))
                                path.addCurve(to: CGPoint(x: 100, y: 50), control1: CGPoint(x: 40, y: 150), control2: CGPoint(x: 60, y: 50))
                                path.addCurve(to: CGPoint(x: 200, y: 120), control1: CGPoint(x: 140, y: 50), control2: CGPoint(x: 160, y: 120))
                                path.addCurve(to: CGPoint(x: 350, y: 80), control1: CGPoint(x: 260, y: 120), control2: CGPoint(x: 280, y: 80))
                            }.stroke(AppColors.textPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)).frame(height: 200).padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                Text("\(dailyData.map{$0.tempMax}.max() ?? 0)°").font(.system(size: 14, weight: .bold)).foregroundColor(AppColors.background).padding(.vertical, 4).padding(.horizontal, 10).background(AppColors.accentYellow).cornerRadius(12)
                            }.offset(x: -40, y: -45)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📅 14-DAY FORECAST").font(.system(size: 12, weight: .bold)).foregroundColor(AppColors.textTertiary).tracking(1)
                        VStack(spacing: 0) {
                            ForEach(Array(dailyData.enumerated()), id: \.offset) { index, day in
                                HStack {
                                    Text(day.dateLabel).font(.system(size: 18, weight: .medium)).foregroundColor(AppColors.textPrimary).frame(width: 120, alignment: .leading)
                                    Text(day.emoji).font(.system(size: 26))
                                    Spacer()
                                    HStack(spacing: 15) {
                                        Text("\(day.tempMin)°").font(.system(size: 18, weight: .medium)).foregroundColor(AppColors.textTertiary)
                                        Text("\(day.tempMax)°").font(.system(size: 18, weight: .semibold)).foregroundColor(AppColors.textPrimary)
                                    }
                                }.padding(.vertical, 15)
                                if index < dailyData.count - 1 { Divider().background(AppColors.border) }
                            }
                        }.padding(.horizontal, 20).background(AppColors.card).cornerRadius(25)
                    }
                    Color.clear.frame(height: 40)
                }.padding(.horizontal, 20)
            }.background(AppColors.background)
        }.ignoresSafeArea()
    }
}