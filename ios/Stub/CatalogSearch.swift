import Foundation
import MapKit
import SwiftUI

struct MovieCatalogItem: Identifiable, Hashable {
    let id: Int
    let title: String
    let creator: String
    let releaseYear: String
    let artworkURL: URL?
}

@MainActor
final class MovieCatalogSearch: ObservableObject {
    @Published private(set) var results: [MovieCatalogItem] = []
    @Published private(set) var isSearching = false
    @Published private(set) var message: String?

    private var task: Task<Void, Never>?

    func search(_ query: String, language: AppLanguage) {
        task?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            message = nil
            isSearching = false
            return
        }

        task = Task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            isSearching = true
            message = nil
            defer { isSearching = false }

            do {
                var components = URLComponents(string: "https://itunes.apple.com/search")!
                components.queryItems = [
                    URLQueryItem(name: "term", value: trimmed),
                    URLQueryItem(name: "media", value: "movie"),
                    URLQueryItem(name: "entity", value: "movie"),
                    URLQueryItem(name: "country", value: language == .zh ? "CN" : "US"),
                    URLQueryItem(name: "limit", value: "12")
                ]
                var request = URLRequest(url: components.url!)
                request.timeoutInterval = 10
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                    throw URLError(.badServerResponse)
                }
                let payload = try JSONDecoder().decode(SearchResponse.self, from: data)
                guard !Task.isCancelled else { return }
                results = payload.results.map { item in
                    MovieCatalogItem(
                        id: item.trackID,
                        title: item.trackName,
                        creator: item.artistName ?? "",
                        releaseYear: item.releaseDate.map { String($0.prefix(4)) } ?? "",
                        artworkURL: item.artworkURL100.flatMap(URL.init(string:))
                    )
                }
                if results.isEmpty {
                    message = language == .zh ? "资料库里没有找到，可以直接使用这个片名。" : "No database match. You can still use this title."
                }
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                message = language == .zh ? "暂时无法连接电影资料库，可以直接使用这个片名。" : "Movie search is unavailable. You can still use this title."
            }
        }
    }
}

private struct SearchResponse: Decodable {
    let results: [SearchResult]
}

private struct SearchResult: Decodable {
    let trackID: Int
    let trackName: String
    let artistName: String?
    let releaseDate: String?
    let artworkURL100: String?

    enum CodingKeys: String, CodingKey {
        case trackID = "trackId"
        case trackName
        case artistName
        case releaseDate
        case artworkURL100 = "artworkUrl100"
    }
}

struct PlaceCatalogItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let subtitle: String
}

@MainActor
final class PlaceCatalogSearch: NSObject, ObservableObject, @preconcurrency MKLocalSearchCompleterDelegate {
    @Published private(set) var results: [PlaceCatalogItem] = []

    private let completer = MKLocalSearchCompleter()
    private var language: AppLanguage = .zh

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func search(_ query: String, language: AppLanguage) {
        self.language = language
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            results = []
        } else {
            completer.queryFragment = trimmed
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results.prefix(8).map {
            PlaceCatalogItem(name: $0.title, subtitle: $0.subtitle)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

struct MovieSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var catalog = MovieCatalogSearch()
    @State private var query = ""
    let onSelect: (MovieCatalogItem) -> Void

    var body: some View {
        let palette = StubPalette(colorScheme)
        NavigationStack {
            Group {
                if catalog.isSearching && catalog.results.isEmpty {
                    ProgressView(language == .zh ? "正在找电影…" : "Searching movies…")
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    ContentUnavailableView(
                        language == .zh ? "搜索电影" : "Find a movie",
                        systemImage: "film.stack",
                        description: Text(language == .zh ? "输入片名，选择正确的电影条目。" : "Type a title and choose the right movie.")
                    )
                } else if let message = catalog.message, catalog.results.isEmpty {
                    VStack(spacing: 18) {
                        ContentUnavailableView(
                            language == .zh ? "没有匹配条目" : "No database match",
                            systemImage: "magnifyingglass",
                            description: Text(message)
                        )
                        manualTitleButton(palette)
                    }
                    .padding(.horizontal, 28)
                } else {
                    List {
                        ForEach(catalog.results) { movie in
                            Button {
                                onSelect(movie)
                                dismiss()
                            } label: {
                                HStack(spacing: 13) {
                                    AsyncImage(url: movie.artworkURL) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Image(systemName: "film").foregroundStyle(palette.tertiaryText)
                                    }
                                    .frame(width: 52, height: 72)
                                    .background(palette.sunken)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(movie.title).font(.subheadline.weight(.semibold)).foregroundStyle(palette.primaryText)
                                        Text([movie.releaseYear, movie.creator].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.caption)
                                            .foregroundStyle(palette.secondaryText)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        Section {
                            manualTitleButton(palette)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .stubScreenBackground(palette)
            .navigationTitle(language == .zh ? "选择电影" : "Choose Movie")
            .stubInlineNavigationTitle()
            .searchable(text: $query, prompt: language == .zh ? "片名" : "Movie title")
            .onChange(of: query) { _, value in catalog.search(value, language: language) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language == .zh ? "取消" : "Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func manualTitleButton(_ palette: StubPalette) -> some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            Button {
                onSelect(MovieCatalogItem(id: trimmed.hashValue, title: trimmed, creator: "", releaseYear: "", artworkURL: nil))
                dismiss()
            } label: {
                Label(language == .zh ? "使用“\(trimmed)”" : "Use “\(trimmed)”", systemImage: "text.cursor")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.brand)
        }
    }
}

struct PlaceSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.stubLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var catalog = PlaceCatalogSearch()
    @State private var query = ""
    let title: String
    let prompt: String
    let onSelect: (PlaceCatalogItem) -> Void

    var body: some View {
        let palette = StubPalette(colorScheme)
        NavigationStack {
            Group {
                if query.isEmpty {
                    ContentUnavailableView(
                        title,
                        systemImage: "mappin.and.ellipse",
                        description: Text(language == .zh ? "搜索影院、场馆、餐厅或地点。" : "Search cinemas, venues, restaurants or places.")
                    )
                } else {
                    List {
                        ForEach(catalog.results) { place in
                            Button {
                                onSelect(place)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(palette.brand)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(place.name).font(.subheadline.weight(.semibold)).foregroundStyle(palette.primaryText)
                                        if !place.subtitle.isEmpty {
                                            Text(place.subtitle).font(.caption).foregroundStyle(palette.secondaryText).lineLimit(2)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        if catalog.results.isEmpty {
                            Section {
                                Button {
                                    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                                    onSelect(PlaceCatalogItem(name: trimmed, subtitle: ""))
                                    dismiss()
                                } label: {
                                    Label(language == .zh ? "使用这个名称" : "Use this name", systemImage: "text.cursor")
                                }
                                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            } footer: {
                                Text(language == .zh ? "没有匹配地点时，也可以保留票面上的原名称。" : "Keep the name from the ticket when there is no match.")
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .stubScreenBackground(palette)
            .navigationTitle(title)
            .stubInlineNavigationTitle()
            .searchable(text: $query, prompt: prompt)
            .onChange(of: query) { _, value in catalog.search(value, language: language) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language == .zh ? "取消" : "Cancel") { dismiss() }
                }
            }
        }
    }
}
