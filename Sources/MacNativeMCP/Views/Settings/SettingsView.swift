import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            ServersSettingsTab()
                .tabItem { Label("Servers", systemImage: "server.rack") }
            NexlayerSettingsTab()
                .tabItem { Label("Nexlayer", systemImage: "cloud") }
            AppearanceSettingsTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
        }
        .frame(width: 500, height: 400)
        .background(AppColors.surface)
    }
}

// MARK: - Servers Tab

struct ServersSettingsTab: View {
    @Environment(AppState.self) private var appState
    @State private var selectedId: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedId) {
                ForEach(appState.servers) { server in
                    ServerRow(server: server, appState: appState)
                        .tag(server.id)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Divider()

            HStack(spacing: 4) {
                Button {
                    let blank = AppState.ServerConfig()
                    appState.addServer(blank)
                    selectedId = blank.id
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                Button {
                    if let id = selectedId {
                        appState.removeServer(id: id)
                        selectedId = nil
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedId == nil)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

private struct ServerRow: View {
    let server: AppState.ServerConfig
    let appState: AppState

    @State private var name: String
    @State private var command: String

    init(server: AppState.ServerConfig, appState: AppState) {
        self.server = server
        self.appState = appState
        _name = State(initialValue: server.name)
        _command = State(initialValue: server.command)
    }

    var body: some View {
        HStack {
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .onChange(of: name) { _, newValue in
                    var updated = server
                    updated.name = newValue
                    appState.updateServer(updated)
                }

            TextField("Command", text: $command)
                .textFieldStyle(.roundedBorder)
                .onChange(of: command) { _, newValue in
                    var updated = server
                    updated.command = newValue
                    appState.updateServer(updated)
                }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Nexlayer Tab

private struct NexlayerSettingsTab: View {
    @AppStorage("nexlayerNamespace") private var namespace: String = "amiable-beetle"

    var body: some View {
        Form {
            TextField("Default Namespace", text: $namespace, prompt: Text("e.g. amiable-beetle"))
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance Tab

struct AppearanceSettingsTab: View {
    @AppStorage("colorScheme") private var colorScheme: String = "System"
    @AppStorage("codeFontSize") private var fontSize: Double = 13
    @AppStorage("codeFont") private var codeFont: String = "SF Mono"

    private let colorSchemes = ["Dark", "Light", "System"]
    private let codeFonts = ["SF Mono", "Menlo", "Courier New"]

    var body: some View {
        Form {
            Picker("Color Scheme", selection: $colorScheme) {
                ForEach(colorSchemes, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)

            LabeledContent("Font Size: \(Int(fontSize))pt") {
                Slider(value: $fontSize, in: 11...16, step: 1)
                    .frame(width: 200)
            }

            Picker("Code Font", selection: $codeFont) {
                ForEach(codeFonts, id: \.self) { font in
                    Text(font).font(.custom(font, size: 13)).tag(font)
                }
            }
            .pickerStyle(.menu)
        }
        .formStyle(.grouped)
        .padding()
    }
}
