import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case trips
    case wall
    case profile

    var id: String { rawValue }

    func label(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.home, .zh): "存根"
        case (.home, .en): "Stubs"
        case (.trips, .zh): "旅册"
        case (.trips, .en): "Trips"
        case (.wall, .zh): "墙"
        case (.wall, .en): "Wall"
        case (.profile, .zh): "回顾"
        case (.profile, .en): "Review"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .trips: "book.closed"
        case .wall: "square.grid.2x2"
        case .profile: "clock.arrow.circlepath"
        }
    }
}

enum EditorDestination: Identifiable {
    case add
    case edit(UUID)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let id): "edit-\(id.uuidString)"
        }
    }
}

struct AppShell: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("stub.native.language") private var languageRaw = AppLanguage.zh.rawValue
    @AppStorage("stub.native.appearance") private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var selectedTab: AppTab = .home
    @State private var editorDestination: EditorDestination?

    private var language: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .zh }
    private var appearance: AppearanceMode { AppearanceMode(rawValue: appearanceRaw) ?? .system }

    var body: some View {
        let palette = StubPalette(colorScheme)
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(onEdit: { editorDestination = .edit($0) })
                    .stubNavigationDestinations(onEdit: { editorDestination = .edit($0) })
            }
            .tag(AppTab.home)

            NavigationStack {
                TripsView(onEdit: { editorDestination = .edit($0) })
                    .stubNavigationDestinations(onEdit: { editorDestination = .edit($0) })
            }
            .tag(AppTab.trips)

            NavigationStack {
                WallView(onEdit: { editorDestination = .edit($0) })
                    .stubNavigationDestinations(onEdit: { editorDestination = .edit($0) })
            }
            .tag(AppTab.wall)

            NavigationStack {
                ProfileView(
                    languageRaw: $languageRaw,
                    appearanceRaw: $appearanceRaw
                )
            }
            .tag(AppTab.profile)
        }
        .stubNativeTabBarHidden()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StubTabBar(
                selectedTab: $selectedTab,
                language: language,
                palette: palette,
                onAdd: { editorDestination = .add }
            )
            .background(palette.canvas.opacity(0.98).ignoresSafeArea())
        }
        .environment(\.stubLanguage, language)
        .environment(\.locale, Locale(identifier: language.localeIdentifier))
        .preferredColorScheme(appearance.colorScheme)
        .sheet(item: $editorDestination) { destination in
            StubEditorView(destination: destination)
                .environment(\.stubLanguage, language)
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["STUB_QA_EDITOR"] == "1" {
                editorDestination = .add
            }
            #endif
        }
    }
}

private struct StubTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedTab: AppTab
    @Namespace private var tabSelectionNamespace
    let language: AppLanguage
    let palette: StubPalette
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            tabButton(.home)
            tabButton(.trips)
            addButton
            tabButton(.wall)
            tabButton(.profile)
        }
        .padding(.horizontal, 8)
        .frame(height: 68)
        .background(palette.surface.opacity(0.97), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(palette.border, lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.09), radius: 16, y: 7)
        .padding(.horizontal, 18)
        .padding(.top, 7)
        .padding(.bottom, 5)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.22, extraBounce: 0)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                    .frame(height: 20)
                Text(tab.label(language))
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? palette.brand : palette.primaryText)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.brandSoft.opacity(0.72))
                        .matchedGeometryEffect(id: "selectedTab", in: tabSelectionNamespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label(language))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color(hex: 0xFFF8F0))
                .frame(width: 50, height: 50)
                .background(palette.brand, in: Circle())
                .overlay(Circle().stroke(palette.surface, lineWidth: 3))
                .shadow(color: palette.brand.opacity(0.25), radius: 8, y: 3)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(language == .zh ? "留下一张" : "Add a Stub")
        .accessibilityIdentifier("addStubButton")
    }
}

private extension AppearanceMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private extension View {
    @ViewBuilder
    func stubNativeTabBarHidden() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .tabBar)
        #else
        self
        #endif
    }

    func stubNavigationDestinations(onEdit: @escaping (UUID) -> Void) -> some View {
        navigationDestination(for: UUID.self) { id in
            StubDetailView(recordID: id, onEdit: onEdit)
        }
    }
}
