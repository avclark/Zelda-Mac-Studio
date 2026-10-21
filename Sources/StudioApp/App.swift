import SwiftUI
import AppKit
import StudioCore

@main struct ZeldaMacStudioApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup("Zelda Mac Studio") { StudioView().environmentObject(model).frame(minWidth: 1060, minHeight: 720) }
        .defaultSize(width: 1240, height: 840)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Mod…") { model.importMod() }.keyboardShortcut("i").disabled(model.workspace == nil || model.busy)
                Button("Refresh Workspace") { model.refresh() }.keyboardShortcut("r").disabled(model.workspace == nil || model.busy)
            }
        }
    }
}

struct StudioView: View {
    @EnvironmentObject var model: AppModel
    @State private var naming: NameAction?
    let sections = [("Library", "square.stack.3d.up"), ("Environments", "square.on.square"), ("Mods", "shippingbox"), ("Snapshots", "clock.arrow.circlepath"), ("Runtimes", "desktopcomputer"), ("Settings & Diagnostics", "gearshape")]
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 18) {
                Label("ZELDA MAC STUDIO", systemImage: "leaf.fill").font(.headline).foregroundStyle(.teal).padding(.top, 18)
                List(selection: $model.section) { ForEach(sections, id: \.0) { title, icon in Label(title, systemImage: icon).tag(title) } }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 6) {
                    Text("A safe place to experiment").font(.caption.bold())
                    Text("Local tools · independent adventures").font(.caption).foregroundStyle(.secondary)
                }.padding(.bottom, 16)
            }.padding(.horizontal, 12).navigationSplitViewColumnWidth(min: 210, ideal: 235)
        } detail: {
            VStack(spacing: 0) {
                if model.workspace == nil { onboarding }
                else {
                    switch model.section {
                    case "Library": library
                    case "Environments": environments
                    case "Mods": mods
                    case "Snapshots": snapshots
                    case "Runtimes": runtimes
                    default: settings
                    }
                }
                Divider()
                HStack(spacing: 10) {
                    if model.busy { ProgressView().controlSize(.small) }
                    else { Image(systemName: "info.circle").foregroundStyle(.secondary) }
                    Text(model.status).font(.caption).lineLimit(2)
                    Spacer()
                }.padding(12).background(.bar)
            }.disabled(model.busy)
        }
        .sheet(item: $naming) { action in NameSheet(action: action) { name, includeSaves in
            switch action.kind {
            case "create": model.create(name)
            case "clone": model.clone(name, saves: includeSaves)
            case "rename": model.rename(name)
            default: model.snapshot(name)
            }
        } }
        .sheet(item: $model.preview) { preview in
            VStack(alignment: .leading, spacing: 18) {
                Text(preview.title).font(.title2.bold())
                ScrollView { Text(preview.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(minHeight: 180, maxHeight: 450)
                HStack { Button("Close") { model.preview = nil }.keyboardShortcut(.cancelAction); Spacer()
                    if let title = preview.actionTitle { Button(title) { model.preview = nil; preview.action?() }.buttonStyle(.borderedProminent) }
                }
            }.padding(28).frame(width: 620)
        }
        .alert("Operation stopped", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
    }
    var onboarding: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "square.on.square.dashed").font(.system(size: 60)).foregroundStyle(.teal)
            Text("Keep your adventure.\nTry something new.").font(.system(size: 38, weight: .bold, design: .rounded))
            Text("Create independent environments, try asset mods and restore a known-good snapshot. Start with a private working folder.").font(.title3).foregroundStyle(.secondary).frame(maxWidth: 620)
            HStack {
                Button("Use Application Support") { model.defaultWorkspace() }.buttonStyle(.borderedProminent)
                Button("Choose Workspace…") { model.chooseWorkspace() }
            }
            Label("Ready: local environment, mod and snapshot tools", systemImage: "checkmark.circle").foregroundStyle(.teal)
            Label("Blocked: game launch needs a clean game and verified runtime integration", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            Text("Existing games, keys, saves and emulator installations are never scanned or adopted automatically.").font(.callout).foregroundStyle(.secondary)
        }.padding(50).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
    func pageHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(title).font(.largeTitle.bold()); Text(subtitle).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 12)
    }
    var library: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            pageHeader("Your library", "Independent adventures. Reversible experiments.")
            HStack(spacing: 18) { stat("Environments", model.available.count, "square.on.square"); stat("Mod packages", model.state.mods.count, "shippingbox"); stat("Snapshots", model.state.snapshots.count, "clock.arrow.circlepath") }
            GroupBox { VStack(alignment: .leading, spacing: 14) {
                Text("Clone & Experiment").font(.title2.bold())
                Text("Create an adventure, clone it, enable a mod in the clone, preview and deploy its laboratory overlay, then restore a snapshot. Your original stays independent.")
                HStack { Button("Create Environment") { naming = .create }.buttonStyle(.borderedProminent); Button("Create Synthetic Demo") { model.demo() }; Button("Open Environments") { model.section = "Environments" } }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading) }
            GroupBox("Portable library") { VStack(alignment: .leading, spacing: 12) {
                Text("Publish immutable versions for local transfer between Macs. Pull verifies every checksum and preserves divergent branches.")
                HStack { Button(model.portable == nil ? "Choose Portable Folder…" : "Change Portable Folder…") { model.choosePortable() }; Button("Pull Publication…") { model.pull() } }
                Text("Active runtime saves, keys, game images, firmware and caches are excluded. Publishing options are available on each environment.").font(.caption).foregroundStyle(.secondary)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading) }
            readinessBanner
        }.padding(30) }
    }
    func stat(_ title: String, _ count: Int, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) { Image(systemName: icon).foregroundStyle(.teal); Text("\(count)").font(.largeTitle.bold()); Text(title).foregroundStyle(.secondary) }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }
    var readinessBanner: some View {
        Label { Text("Why can’t I play yet? The inventoried base game is damaged, native gameplay needs macOS 26+, and isolated runtime launch is not verified. You can use all local laboratory workflows now.").font(.callout) } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
    var environments: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("Adventures").font(.title2.bold()); Spacer(); Button { naming = .create } label: { Image(systemName: "plus") }.help("Create Environment") }
                List(selection: $model.selected) { ForEach(model.available) { env in
                    VStack(alignment: .leading, spacing: 5) { Label(env.name, systemImage: env.archived ? "archivebox" : "square.on.square").font(.headline); Text("\(env.enabledMods.count) mods · \(env.backend == .laboratory ? "Laboratory" : "Runtime blocked")").font(.caption).foregroundStyle(.secondary) }.padding(.vertical, 6).tag(env.id)
                } }.listStyle(.inset)
            }.padding(16).frame(minWidth: 210, idealWidth: 245, maxWidth: 300)
            if let env = model.current, !env.trashed { EnvironmentDetail(env: env, naming: $naming).environmentObject(model) }
            else { ContentUnavailableView { Label("Your next adventure", systemImage: "square.on.square") } description: { Text("Create an environment or choose one from the list.") } actions: { Button("Create Environment") { naming = .create } } }
        }
    }
    var mods: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            pageHeader("Mod library", "Original imports are preserved and checksummed. Compatibility stays explicit.")
            Button("Import ZIP or Folder…") { model.importMod() }.buttonStyle(.borderedProminent)
            if model.state.mods.isEmpty { Text("Drop a ZIP archive or folder here, or create a synthetic demo from Library.").foregroundStyle(.secondary).padding(.vertical, 40) }
            ForEach(model.state.mods) { mod in
                GroupBox { VStack(alignment: .leading, spacing: 8) {
                    Text(mod.name).font(.headline)
                    Text("Detected: \(mod.formats.joined(separator: ", ")) · \(mod.files.count) files · \(mod.origin)")
                    Text("Version: \(mod.version) · Runtime compatibility: not checked · Gameplay: unverified").font(.caption).foregroundStyle(.secondary)
                    Text("Content SHA-256: \(mod.id)").font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    DisclosureGroup("Imported file manifest") { ForEach(mod.files.keys.sorted(), id: \.self) { Text($0).font(.caption).frame(maxWidth: .infinity, alignment: .leading) } }
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading) }
            }
        }.padding(30) }.dropDestination(for: URL.self) { urls, _ in guard let first = urls.first, !model.busy else { return false }; model.importMod(first); return true }
    }
    var snapshots: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            pageHeader("Snapshots", "Immutable configuration, overlay and managed save checkpoints.")
            if model.state.snapshots.isEmpty { Text("Create a snapshot inside an environment. Deployment also records a recovery snapshot automatically.").foregroundStyle(.secondary) }
            ForEach(model.state.snapshots.reversed()) { snap in
                HStack { VStack(alignment: .leading, spacing: 5) { Text(snap.label).font(.headline); Text("\(snap.environment.name) · \(snap.created.formatted()) · \(snap.manifest.count) files").font(.caption).foregroundStyle(.secondary) }; Spacer()
                    Button("Preview Restore…") { model.previewRestore(snap) }.disabled(model.state.environments.first(where: { $0.id == snap.environment.id })?.trashed != false)
                }.padding(16).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }
        }.padding(30) }
    }
    var runtimes: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            pageHeader("Runtime readiness", "The native manager is ready on Sonoma. Game execution has separate requirements.")
            ForEach(Backend.allCases) { backend in
                let adapter = GuardedRuntimeAdapter(backend), readiness = adapter.readiness()
                GroupBox(backend.title) { VStack(alignment: .leading, spacing: 10) {
                    Text(readiness.status).font(.headline).foregroundStyle(backend == .laboratory ? .teal : .orange)
                    ForEach(readiness.reasons, id: \.self) { Text($0).font(.callout) }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading) }
            }
            GroupBox("Machine-local references") { VStack(alignment: .leading, spacing: 12) {
                Text("Register references only. No file contents are read, copied or validated, and these bookmarks are excluded from portable exports.").font(.callout).foregroundStyle(.secondary)
                ForEach(["Runtime app", "Base game", "Update", "Keys reference"], id: \.self) { kind in HStack { Text(kind).frame(width: 130, alignment: .leading); Text(model.registrations[kind] ?? "Not registered").font(.caption); Spacer(); Button("Choose…") { model.register(kind) } } }
            }.padding(12) }
            Text("Resource merging, graphics presets and cross-runtime save migration: unavailable pending verified integration.").foregroundStyle(.secondary)
        }.padding(30) }
    }
    var settings: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            pageHeader("Settings & Diagnostics", "Local control, clear status and recoverable history.")
            GroupBox("Folders") { VStack(alignment: .leading, spacing: 10) {
                Text("Workspace: \(model.workspace?.lastPathComponent ?? "Not selected")")
                HStack { Button("Choose Workspace…") { model.chooseWorkspace() }; Button("Reveal Workspace") { if let url = model.workspace { NSWorkspace.shared.open(url) } }; Button("Refresh") { model.refresh() } }
                Text("Portable folder: \(model.portable?.lastPathComponent ?? "Not selected")")
                Button("Choose Portable Folder…") { model.choosePortable() }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading) }
            GroupBox("Recoverable Trash") { VStack(alignment: .leading, spacing: 10) {
                let items = model.state.environments.filter(\.trashed)
                if items.isEmpty { Text("Trash is empty.").foregroundStyle(.secondary) }
                ForEach(items) { env in HStack { Text(env.name); Spacer(); Button("Recover") { model.run("Recover environment") { try $0.setTrashed(env.id, false); return env.id } } } }
                Text("No automatic permanent deletion. Old revisions and interrupted stages are retained locally.").font(.caption).foregroundStyle(.secondary)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading) }
            Button("Preview Sanitized Diagnostics…") { model.diagnostics() }
            GroupBox("Recent operations") { VStack(alignment: .leading, spacing: 8) { ForEach(Array(model.state.events.suffix(20).reversed().enumerated()), id: \.offset) { _, event in Text(event).font(.caption).textSelection(.enabled) } }.padding(10).frame(maxWidth: .infinity, alignment: .leading) }
            readinessBanner
        }.padding(30) }
    }
}

struct NameAction: Identifiable {
    var id: String { kind }; let kind: String; let title: String; let initial: String
    static let create = NameAction(kind: "create", title: "Create Environment", initial: "Main Adventure")
}
struct NameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let action: NameAction; var submit: (String, Bool) -> Void
    @State private var name = ""
    @State private var saves = true
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(action.title).font(.title2.bold())
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            if action.kind == "clone" { Toggle("Copy independent managed save state", isOn: $saves); Text("Configuration and overlay files are always copied. Original emulator saves are never accessed.").font(.caption).foregroundStyle(.secondary) }
            HStack { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button(action.title) { dismiss(); submit(name, saves) }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(28).frame(width: 450).onAppear { name = action.initial }
    }
}

struct EnvironmentDetail: View {
    @EnvironmentObject var model: AppModel
    let env: Adventure
    @Binding var naming: NameAction?
    @State private var notes = ""
    @State private var version = ""
    @State private var includeSaves = false
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) { VStack(alignment: .leading, spacing: 7) { Text(env.name).font(.largeTitle.bold()); Text("Tears of the Kingdom · \(env.gameVersion) · Generation \(env.generation)").foregroundStyle(.secondary) }; Spacer()
                Menu { Button("Rename…") { naming = NameAction(kind: "rename", title: "Rename Environment", initial: env.name) }; Button(env.archived ? "Unarchive" : "Archive") { model.run("Update archive state") { try $0.update(env.id, archived: !env.archived); return nil } }; Button("Move to Trash…", role: .destructive) { model.trash(env) } } label: { Image(systemName: "ellipsis.circle") }
            }
            HStack {
                Button("Clone & Experiment") { naming = NameAction(kind: "clone", title: "Clone & Experiment", initial: "Experimental Adventure") }.buttonStyle(.borderedProminent)
                Button("Snapshot…") { naming = NameAction(kind: "snapshot", title: "Create Snapshot", initial: "Known good") }
                Button("Play — unavailable") {}.disabled(true).help("See Runtime readiness for the game, OS and integration blockers.")
            }
            HStack(spacing: 20) { Label("Files: validated on import/deploy", systemImage: "checkmark.shield"); Label("Gameplay: unverified", systemImage: "questionmark.circle") }.font(.caption).foregroundStyle(.secondary)
            GroupBox("Mod experiment") { VStack(alignment: .leading, spacing: 12) {
                HStack { Text("\(env.enabledMods.count) enabled · selection is independent").font(.headline); Spacer(); Button("Try a Mod…") { model.importMod() } }
                if model.state.mods.isEmpty { Text("Import a ZIP or folder, or create synthetic sample content in Library.").foregroundStyle(.secondary) }
                ForEach(env.enabledMods, id: \.self) { id in if let mod = model.state.mods.first(where: { $0.id == id }) { modRow(mod, enabled: true) } }
                ForEach(model.state.mods.filter { !env.enabledMods.contains($0.id) }) { mod in modRow(mod, enabled: false) }
                Divider()
                Button("Preview Deployment…") { model.previewDeployment(env) }
                Text("A selection change takes effect after deployment. Conflicting paths stop deployment; load order never silently merges files.").font(.caption).foregroundStyle(.secondary)
            }.padding(12) }
            GroupBox("Snapshots & comparison") { VStack(alignment: .leading, spacing: 12) {
                Button("Copy Save Folder…") { model.importSaves(env) }
                let snapshots = model.state.snapshots.filter { $0.environment.id == env.id }
                if snapshots.isEmpty { Text("No snapshots yet. Create one before experimenting.").foregroundStyle(.secondary) }
                ForEach(snapshots.reversed()) { snap in HStack { VStack(alignment: .leading) { Text(snap.label); Text(snap.created.formatted()).font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("Compare") { model.compare(env, snap.environment) }; Button("Revert…") { model.previewRestore(snap) } } }
                Menu("Compare with Environment") { ForEach(model.available.filter { $0.id != env.id }) { other in Button(other.name) { model.compare(env, other) } } }.disabled(model.available.count < 2)
            }.padding(12) }
            GroupBox("Configuration & compatibility notes") { VStack(alignment: .leading, spacing: 12) {
                Picker("Target", selection: Binding(get: { env.backend }, set: { backend in model.run("Change target backend") { try $0.update(env.id, backend: backend); return nil } })) { ForEach(Backend.allCases) { Text($0.title).tag($0) } }
                HStack { TextField("Game version", text: $version); Button("Save Version") { model.run("Record game version") { try $0.update(env.id, gameVersion: version); return nil } } }
                TextEditor(text: $notes).font(.body).frame(height: 85).overlay(RoundedRectangle(cornerRadius: 5).stroke(.quaternary))
                Button("Save Notes") { model.run("Save compatibility notes") { try $0.update(env.id, notes: notes); return nil } }
                Text("Record test instructions and observations here. Save compatibility is unverified; no cross-runtime migration is attempted.").font(.caption).foregroundStyle(.secondary)
            }.padding(12) }
            GroupBox("Portable transfer") { VStack(alignment: .leading, spacing: 12) {
                Toggle("Include immutable managed save checkpoints", isOn: $includeSaves)
                Text("Off by default. Use local transfer for private saves. Only committed checkpoints are included; active runtime directories and local registrations are excluded.").font(.caption).foregroundStyle(.secondary)
                HStack { Button(model.portable == nil ? "Choose Portable Folder…" : "Publish New Version") { model.publish(env, saves: includeSaves) }; Button("Pull Publication…") { model.pull() } }
            }.padding(12) }
        }.padding(28) }.onAppear { notes = env.notes; version = env.gameVersion }.onChange(of: env.id) { _, _ in notes = env.notes; version = env.gameVersion }.onChange(of: env.notes) { _, value in notes = value }.onChange(of: env.gameVersion) { _, value in version = value }
    }
    func modRow(_ mod: ModPackage, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Toggle(isOn: Binding(get: { enabled }, set: { _ in model.toggle(mod, in: env) })) { VStack(alignment: .leading) { Text(mod.name); Text(mod.formats.joined(separator: ", ") + " · compatibility unknown").font(.caption).foregroundStyle(.secondary) } }
            Spacer()
            if enabled {
                Button { model.move(mod.id, offset: -1, in: env) } label: { Image(systemName: "arrow.up") }.help("Move earlier").disabled(env.enabledMods.first == mod.id)
                Button { model.move(mod.id, offset: 1, in: env) } label: { Image(systemName: "arrow.down") }.help("Move later").disabled(env.enabledMods.last == mod.id)
            }
        }
    }
}
