import AppKit
import SwiftUI
@preconcurrency import StudioCore
import UniformTypeIdentifiers

@MainActor final class AppModel: ObservableObject {
    @Published var state = LibraryState()
    @Published var workspace: URL?
    @Published var portable: URL?
    @Published var selected: UUID?
    @Published var section = "Environments"
    @Published var busy = false
    @Published var status = "Choose a workspace to get started."
    @Published var error: String?
    @Published var preview: Preview?
    @Published var registrations: [String: String] = [:]
    private var store: LibraryStore?
    private let worker = DispatchQueue(label: "studio.filesystem", qos: .userInitiated)
    private var scopes: [URL] = []
    struct Preview: Identifiable { let id = UUID(); var title: String; var text: String; var actionTitle: String?; var action: (() -> Void)? }
    var current: Adventure? { state.environments.first { $0.id == selected } }
    var available: [Adventure] { state.environments.filter { !$0.trashed } }
    init() {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--workspace"), args.indices.contains(index+1) { openWorkspace(URL(fileURLWithPath: args[index+1]), persist: false) }
        else if let url = resolve("workspace") { openWorkspace(url, persist: false) }
        portable = resolve("portable")
        for kind in ["Runtime app", "Base game", "Update", "Keys reference"] {
            if resolve("reference-" + kind) != nil { registrations[kind] = "Reference registered · not validated" }
        }
    }
    func resolve(_ key: String) -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
            guard !stale else { status = "A saved folder reference needs to be selected again."; return nil }
            if url.startAccessingSecurityScopedResource() { scopes.append(url) }
            return url
        } catch { status = "A saved folder is unavailable. Select it again."; return nil }
    }
    func remember(_ url: URL, key: String) throws {
        let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: key)
        if url.startAccessingSecurityScopedResource() { scopes.append(url) }
    }
    func openWorkspace(_ url: URL, persist: Bool = true) {
        do {
            let library = try LibraryStore(root: url, isRuntimeActive: { _ in
                NSWorkspace.shared.runningApplications.contains { app in
                    let name = (app.localizedName ?? "").lowercased()
                    return ["ryujinx", "ryubing", "tears of the kingdom", "macnativegames", "astris"].contains(where: { name.contains($0) })
                }
            })
            if persist { try remember(url, key: "workspace") }
            store = library; workspace = url; state = library.state; selected = available.first?.id
            status = "Workspace ready. Gameplay remains unavailable; managed experiments are ready."
        } catch { show(error) }
    }
    func defaultWorkspace() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        openWorkspace(base.appendingPathComponent("ZeldaMacStudio/Workspace"))
    }
    func chooseWorkspace() {
        let panel = NSOpenPanel(); panel.title = "Choose an empty or existing Zelda Mac Studio workspace"
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { openWorkspace(url) }
    }
    func choosePortable() {
        let panel = NSOpenPanel(); panel.title = "Choose a separate portable library folder"
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            do { try remember(url, key: "portable"); portable = url; status = "Portable folder selected. Publish creates a new immutable version." } catch { show(error) }
        }
    }
    func run(_ title: String, _ action: @escaping (LibraryStore) throws -> UUID?) {
        guard let store, !busy else { return }
        busy = true; status = title
        worker.async {
            do {
                let selected = try action(store), state = store.state
                DispatchQueue.main.async { self.state = state; if let selected { self.selected = selected }; self.busy = false; self.status = title + " — complete." }
            } catch { DispatchQueue.main.async { self.busy = false; self.show(error) } }
        }
    }
    func show(_ error: Error) {
        self.error = (error as? StudioError)?.localizedDescription ?? "The filesystem operation could not complete. Check free space, folder permissions and whether all files are downloaded locally. Your previous committed state is retained."
        status = "Operation stopped. Review the error before trying again."
    }
    func create(_ name: String) { run("Create environment") { try $0.create(name: name).id } }
    func clone(_ name: String, saves: Bool) { guard let id = selected else { return }; run("Clone & Experiment") { try $0.clone(id, name: name, includeSaves: saves).id } }
    func rename(_ name: String) { guard let id = selected else { return }; run("Rename environment") { try $0.update(id, name: name); return id } }
    func snapshot(_ name: String) { guard let id = selected else { return }; run("Create immutable snapshot") { _ = try $0.snapshot(id, label: name); return id } }
    func refresh() { run("Refresh workspace") { try $0.refresh(); return nil } }
    func toggle(_ mod: ModPackage, in env: Adventure) {
        let ids = env.enabledMods.contains(mod.id) ? env.enabledMods.filter { $0 != mod.id } : env.enabledMods + [mod.id]
        run("Update mod selection") { try $0.setMods(env.id, orderedIDs: ids); return nil }
    }
    func move(_ id: String, offset: Int, in env: Adventure) {
        guard let index = env.enabledMods.firstIndex(of: id), env.enabledMods.indices.contains(index+offset) else { return }
        var ids = env.enabledMods; ids.swapAt(index, index+offset)
        run("Reorder mods") { try $0.setMods(env.id, orderedIDs: ids); return nil }
    }
    func importMod(_ url: URL? = nil) {
        var source = url
        if source == nil {
            let panel = NSOpenPanel(); panel.title = "Import a ZIP mod or folder"; panel.canChooseDirectories = true; panel.canChooseFiles = true
            if panel.runModal() == .OK { source = panel.url }
        }
        guard let source else { return }
        let accessing = source.startAccessingSecurityScopedResource()
        run("Import and validate mod files") { store in defer { if accessing { source.stopAccessingSecurityScopedResource() } }; _ = try store.importMod(source); return nil }
    }
    func previewDeployment(_ env: Adventure) {
        run("Plan overlay changes") { store in
            let plan = try store.plan(env)
            var lines = ["Only this environment's managed overlay changes. A recovery snapshot is created automatically."]
            lines.append("Added: \(plan.added.count) · Changed: \(plan.changed.count) · Removed: \(plan.removed.count)")
            lines.append(plan.blockers.isEmpty ? "File planning passed. Runtime compatibility and gameplay remain unverified." : plan.blockers.joined(separator: "\n\n"))
            lines.append(plan.added.map { "+ " + $0 }.joined(separator: "\n"))
            lines.append(plan.changed.map { "~ " + $0 }.joined(separator: "\n"))
            lines.append(plan.removed.map { "− " + $0 }.joined(separator: "\n"))
            let text = lines.joined(separator: "\n\n")
            DispatchQueue.main.async {
                var preview = Preview(title: "Deployment preview", text: text)
                if plan.canDeploy {
                    preview.actionTitle = "Deploy laboratory overlay"
                    preview.action = { self.run("Deploy verified overlay") { try $0.deploy(env.id, expected: env); return nil } }
                }
                self.preview = preview
            }
            return nil
        }
    }
    func importSaves(_ env: Adventure) {
        let panel = NSOpenPanel(); panel.title = "Choose a save folder to copy; the source stays unchanged"
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        guard panel.runModal() == .OK, let source = panel.url else { return }
        preview = Preview(title: "Copy saves into “\(env.name)” ?", text: "Copy the selected folder “\(source.lastPathComponent)” into a new independent managed revision. This replaces this environment's managed save state only. A Before save import snapshot retains the previous state. The selected source is read-only and never changed.\n\nSave compatibility is unverified. This does not configure or launch an emulator.", actionTitle: "Copy and verify saves", action: {
            let access = source.startAccessingSecurityScopedResource()
            self.run("Copy independent save checkpoint") { store in
                defer { if access { source.stopAccessingSecurityScopedResource() } }
                try store.importManagedSaves(env.id, from: source); return nil
            }
        })
    }
    func previewRestore(_ snap: Snapshot) {
        let saves = snap.manifest.keys.filter { $0.hasPrefix("saves/") }.count
        preview = Preview(title: "Restore “\(snap.label)”", text: "Restore this environment's configuration, \(snap.environment.enabledMods.count) selected mods and \(saves) managed save files. The current revision is retained as a Before restore snapshot. Other environments and original emulator saves are unaffected.\n\nSave compatibility with a game runtime is unverified.", actionTitle: "Restore snapshot", action: { self.run("Restore snapshot") { try $0.restore(snap.id); return snap.environment.id } })
    }
    func compare(_ lhs: Adventure, _ rhs: Adventure) {
        run("Compare environments") { store in
            let text = try store.compare(lhs, rhs)
            DispatchQueue.main.async { self.preview = Preview(title: "\(lhs.name) ↔ \(rhs.name)", text: text) }; return nil
        }
    }
    func trash(_ env: Adventure) {
        preview = Preview(title: "Move “\(env.name)” to Trash?", text: "Its revisions and snapshots are retained. Recover it from Settings & Diagnostics. No permanent deletion is performed.", actionTitle: "Move to recoverable Trash", action: { self.run("Move environment to Trash") { try $0.setTrashed(env.id, true); return nil } })
    }
    func publish(_ env: Adventure, saves: Bool) {
        guard let portable else { choosePortable(); return }
        run("Publish immutable library version") { store in
            let url = try store.publish(env.id, to: portable, includeSaveSnapshots: saves)
            DispatchQueue.main.async { self.preview = Preview(title: "Publication verified", text: "Created \(url.lastPathComponent).\n\nTransfer this complete folder locally, then choose Pull on the other Mac. Incomplete downloads are rejected. Reimporting a matching environment preserves both branches.\n\nIncluded save checkpoints: \(saves ? "Yes" : "No").") }; return nil
        }
    }
    func pull() {
        let panel = NSOpenPanel(); panel.title = "Choose a complete .zmslibrary folder"; panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url { run("Verify and import portable version") { try $0.pull(from: url).id } }
    }
    func register(_ kind: String) {
        let panel = NSOpenPanel(); panel.title = "Register \(kind) as a local reference only"
        panel.canChooseFiles = true; panel.canChooseDirectories = kind == "Runtime app"
        if panel.runModal() == .OK, let url = panel.url {
            do { try remember(url, key: "reference-" + kind); registrations[kind] = "Reference registered · not validated"; status = "Reference saved locally. No contents copied, parsed or promoted to trusted." } catch { show(error) }
        }
    }
    func diagnostics() {
        let report = Diagnostics.report(state)
        preview = Preview(title: "Sanitized diagnostic preview", text: report, actionTitle: "Save this report…", action: {
            let panel = NSSavePanel(); panel.nameFieldStringValue = "Zelda-Studio-Diagnostics.txt"
            if panel.runModal() == .OK, let url = panel.url { do { try report.write(to: url, atomically: true, encoding: .utf8); self.status = "Sanitized report saved." } catch { self.show(error) } }
        })
    }
    func demo() {
        run("Create synthetic demo") { store in
            let env = try store.create(name: "Demo Adventure")
            try store.writeManagedSave(env.id, path: "demo-slot.txt", data: Data("Synthetic demo save. No game data.".utf8))
            _ = try store.snapshot(env.id, label: "Demo starting point")
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Sample Asset Mod")
            defer { try? FileManager.default.removeItem(at: temp.deletingLastPathComponent()) }
            try SafeFiles.directory(temp.appendingPathComponent("romfs/Demo"))
            try Data("Synthetic mod asset. Not a real TOTK resource.".utf8).write(to: temp.appendingPathComponent("romfs/Demo/example.txt"))
            _ = try store.importMod(temp)
            return env.id
        }
    }
}
