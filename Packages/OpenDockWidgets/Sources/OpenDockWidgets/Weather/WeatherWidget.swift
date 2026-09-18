import SwiftUI
import OpenDockKit

struct WeatherWidget: DockWidget {
    static let descriptor = WidgetDescriptor(id: "dev.opendock.weather", name: "Weather",
        summary: "Current conditions and today's high and low for your saved city.",
        symbol: "cloud.sun.fill", category: .weather, supportedSizes: [.medium, .wide])
    func body(context: WidgetContext) -> some View { WeatherView(context: context) }
}

private struct WeatherView: View {
    @Environment(\.dockTheme) private var theme
    @State private var expanded = false
    @State private var place: WeatherPlace?
    @State private var weather: WeatherSnapshot?
    @State private var fahrenheit = false
    @State private var query = ""
    @State private var searchTerm = ""
    @State private var searchRevision = 0
    @State private var results: [WeatherPlace] = []
    @State private var searching = false
    @State private var searchMessage: String?
    @State private var failed = false
    @State private var restored = false
    let context: WidgetContext

    var body: some View {
        Button { expanded.toggle() } label: {
            HStack(spacing: theme.scaled(8)) {
                Image(systemName: weather?.symbol ?? "cloud.sun.fill").symbolRenderingMode(.multicolor).font(theme.heroFont)
                VStack(alignment: .leading, spacing: theme.scaled(1)) {
                    Text(weather.map { temperature($0.temperature) } ?? "Weather").font(weather == nil ? theme.titleFont : theme.statFont)
                    Text(place?.name ?? "Choose a city").font(theme.captionFont).foregroundStyle(.secondary).lineLimit(1)
                    if context.size == .wide, let weather {
                        Text("H \(temperature(weather.high))  L \(temperature(weather.low))").font(theme.captionFont).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }.padding(theme.contentPadding).frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
        }.buttonStyle(.plain)
        .popover(isPresented: $expanded) {
            WidgetDetails(title: place?.name ?? "Weather", symbol: weather?.symbol ?? "cloud.sun") {
                if let weather {
                    HStack {
                        Text(temperature(weather.temperature)).font(theme.heroFont)
                        VStack(alignment: .leading) {
                            Text(weather.condition)
                            Text("Feels like \(temperature(weather.feelsLike))").font(theme.captionFont).foregroundStyle(.secondary)
                        }
                    }
                    Text("High \(temperature(weather.high)) · Low \(temperature(weather.low))").foregroundStyle(.secondary)
                    Text("Updated \(weather.fetchedAt.formatted(date: .omitted, time: .shortened))\(failed ? " · Saved forecast" : "")")
                        .font(theme.captionFont).foregroundStyle(.secondary)
                } else if place != nil {
                    Text(failed ? "Weather is unavailable. We'll retry shortly." : "Loading conditions…").foregroundStyle(.secondary)
                }
                Picker("Temperature", selection: $fahrenheit) {
                    Text("°C").tag(false)
                    Text("°F").tag(true)
                }.pickerStyle(.segmented)
                Divider()
                Text("City").font(theme.titleFont)
                HStack {
                    TextField("Search city", text: $query).textFieldStyle(.roundedBorder).onSubmit { search() }
                    Button("Find") { search() }.buttonStyle(.glass).disabled(query.trimmingCharacters(in: .whitespaces).count < 2 || searching)
                }
                if searching { ProgressView().controlSize(.small) }
                if let searchMessage { Text(searchMessage).foregroundStyle(.secondary) }
                ForEach(results) { result in
                    Button {
                        weather = nil; failed = false; place = result; results = []; searchMessage = nil
                        context.services.storage.set(result, for: "weather.place", instance: context.instanceID)
                        context.services.storage.set(Optional<WeatherSnapshot>.none, for: "weather.cache", instance: context.instanceID)
                    } label: { Text(result.label).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.glass)
                }
                Button("Weather: Open-Meteo · Locations: GeoNames") {
                    context.services.openURL(URL(string: "https://open-meteo.com/")!)
                }.buttonStyle(.link).font(theme.captionFont)
            }.environment(\.dockTheme, theme)
        }
        .onAppear {
            guard !restored else { return }
            place = context.services.storage.get("weather.place", instance: context.instanceID, as: WeatherPlace.self)
            weather = context.services.storage.get("weather.cache", instance: context.instanceID, as: WeatherSnapshot.self)
            fahrenheit = context.services.storage.get("weather.fahrenheit", instance: context.instanceID, as: Bool.self) ?? false
            restored = true
        }
        .onChange(of: fahrenheit) { _, value in
            context.services.storage.set(value, for: "weather.fahrenheit", instance: context.instanceID)
        }
        .task(id: place?.id) {
            guard let place else { return }
            while !Task.isCancelled {
                if weather == nil || Date.now.timeIntervalSince(weather!.fetchedAt) > 900 {
                    do {
                        let updated = try await context.services.weather.forecast(for: place)
                        try Task.checkCancellation()
                        weather = updated; failed = false
                        context.services.storage.set(updated, for: "weather.cache", instance: context.instanceID)
                    } catch {
                        if Task.isCancelled { return }
                        failed = true
                    }
                }
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
        .task(id: searchRevision) {
            guard searchTerm.count >= 2 else { return }
            searching = true; searchMessage = nil
            do {
                let found = try await context.services.weather.search(searchTerm)
                try Task.checkCancellation()
                results = found
                searchMessage = found.isEmpty ? "No cities found. Try another spelling." : nil
            } catch {
                if Task.isCancelled { return }
                searchMessage = "City search is unavailable. Check your connection and retry."
            }
            searching = false
        }
    }
    private func search() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else { return }
        searchTerm = term
        searchRevision += 1
    }
    private func temperature(_ celsius: Double) -> String {
        "\(Int((fahrenheit ? celsius * 9 / 5 + 32 : celsius).rounded()))°"
    }
}
