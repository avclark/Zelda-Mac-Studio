import Foundation

extension LibraryStore {
    @discardableResult public func importMod(_ source: URL) throws -> ModPackage {
        try locked {
            try reload()
            let stage = root.appendingPathComponent("staging/\(UUID().uuidString)")
            let content = stage.appendingPathComponent("content")
            try SafeFiles.directory(stage)
            defer { try? SafeFiles.fm.removeItem(at: stage) }
            let values = try source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw StudioError.invalid("Symbolic-link imports are not allowed.") }
            var originalHash: String?
            if values.isDirectory == true {
                let manifest = try SafeFiles.regularFiles(source)
                for path in manifest.keys { try SafeFiles.rejectPrivateInput(path) }
                try SafeFiles.copyTree(source, content)
            } else {
                guard source.pathExtension.lowercased() == "zip" else { throw StudioError.invalid("Choose a ZIP archive or folder. Other archive formats are unavailable.") }
                let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
                guard size <= ZIPImporter().maxArchive else { throw StudioError.invalid("ZIP exceeds 256 MiB archive limit.") }
                let original = stage.appendingPathComponent("original.zip")
                try SafeFiles.fm.copyItem(at: source, to: original)
                try ZIPImporter().extract(original, to: content)
                originalHash = try SafeFiles.hashFile(original)
            }
            let files = try SafeFiles.regularFiles(content)
            guard !files.isEmpty else { throw StudioError.invalid("The mod contains no files.") }
            let id = try SafeFiles.hash(SafeFiles.encode(files))
            if let existing = state.mods.first(where: { $0.id == id }) { try SafeFiles.verify(packageURL(id), existing.files); return existing }
            let formats = Set(files.keys.map { path -> String in
                let parts = path.lowercased().split(separator: "/").map(String.init)
                return ["romfs", "exefs", "cheats"].first(where: { parts.contains($0) }) ?? (["ips", "pchtxt"].contains((path as NSString).pathExtension.lowercased()) ? "patches" : "unknown")
            }).sorted()
            let mod = ModPackage(id: id, name: try SafeFiles.cleanName(source.deletingPathExtension().lastPathComponent), files: files, formats: formats, imported: Date(), origin: values.isDirectory == true ? "Folder import" : "ZIP import", originalArchiveHash: originalHash)
            let destination = root.appendingPathComponent("packages/\(id)")
            if SafeFiles.fm.fileExists(atPath: destination.path) { // recovery from an interrupted prior catalog commit
                try SafeFiles.verify(destination.appendingPathComponent("content"), files)
            } else { try SafeFiles.fm.moveItem(at: stage, to: destination) }
            var next = state; next.mods.append(mod); try commit(next, event: "Mod imported; file hashes validated. Runtime and gameplay compatibility remain unverified.")
            return mod
        }
    }
    public func setMods(_ id: UUID, orderedIDs: [String]) throws {
        try locked {
            try reload(); var env = try writable(id)
            guard Set(orderedIDs).count == orderedIDs.count, orderedIDs.allSatisfy({ id in state.mods.contains(where: { $0.id == id }) }) else { throw StudioError.invalid("Invalid mod selection.") }
            env.enabledMods = orderedIDs; env.gameplayVerified = false
            var next = state; replace(env, in: &next); try commit(next, event: "Mod selection updated; deployment pending.")
        }
    }
    public func plan(_ env: Adventure) throws -> DeploymentPlan {
        var plan = DeploymentPlan(), normalized: [String: String] = [:]
        if env.backend != .laboratory { plan.blockers.append("Live runtime deployment is unavailable until the adapter's isolated save and mod paths are verified. Use Local mod laboratory to test a staged overlay.") }
        for id in env.enabledMods {
            guard let mod = state.mods.first(where: { $0.id == id }) else { plan.blockers.append("Selected package is missing."); continue }
            try SafeFiles.verify(packageURL(id), mod.files)
            if mod.formats.contains(where: { ["exefs", "cheats", "patches"].contains($0) }) { plan.blockers.append("\(mod.name) contains executable patches or cheats. This deployer supports RomFS asset files only."); continue }
            var recognized = false
            for path in mod.files.keys.sorted() {
                let parts = path.split(separator: "/").map(String.init)
                guard let index = parts.firstIndex(of: "romfs"), index + 1 < parts.count else { continue }
                recognized = true
                let target = parts[index...].joined(separator: "/"), key = target.precomposedStringWithCanonicalMapping.lowercased()
                if normalized[key] != nil { plan.blockers.append("File conflict: \(target). Disable one of the mods; resource merging is unavailable."); continue }
                normalized[key] = target; plan.files[target] = id; plan.hashes[target] = mod.files[path]
            }
            if !recognized { plan.blockers.append("\(mod.name) has no recognized lowercase romfs folder. Format is unsupported or ambiguous.") }
        }
        let old = try SafeFiles.regularFiles(overlayURL(env))
        plan.added = plan.hashes.keys.filter { old[$0] == nil }.sorted()
        plan.changed = plan.hashes.keys.filter { old[$0] != nil && old[$0] != plan.hashes[$0] }.sorted()
        plan.removed = old.keys.filter { plan.hashes[$0] == nil }.sorted()
        return plan
    }
    public func deploy(_ id: UUID, expected: Adventure? = nil) throws {
        try locked {
            try reload(); let old = try writable(id)
            if let expected {
                guard expected.revision == old.revision, expected.enabledMods == old.enabledMods, expected.backend == old.backend else { throw StudioError.invalid("Environment changed after the preview. Review a fresh deployment plan.") }
            }
            let plan = try plan(old)
            guard plan.canDeploy else { throw StudioError.invalid(plan.blockers.joined(separator: "\n")) }
            var env = old; env.revision = UUID(); env.generation += 1; env.gameplayVerified = false
            try stageRevision(from: old, to: env)
            try SafeFiles.fm.removeItem(at: overlayURL(env)); try SafeFiles.directory(overlayURL(env))
            for target in plan.files.keys.sorted() {
                let id = plan.files[target]!
                guard let mod = state.mods.first(where: { $0.id == id }),
                      let source = mod.files.keys.first(where: { $0 == target || $0.hasSuffix("/" + target) }) else { throw StudioError.invalid("Package changed during planning.") }
                let dest = overlayURL(env).appendingPathComponent(target); try SafeFiles.directory(dest.deletingLastPathComponent())
                try SafeFiles.fm.copyItem(at: packageURL(id).appendingPathComponent(source), to: dest)
            }
            try SafeFiles.verify(overlayURL(env), plan.hashes)
            var next = state; next.snapshots.append(try snapshotRecord(old, label: "Before deployment \(env.generation)")); replace(env, in: &next)
            try commit(next, event: "Laboratory overlay deployed and hashes verified. No runtime launched; gameplay unverified.")
        }
    }
}
