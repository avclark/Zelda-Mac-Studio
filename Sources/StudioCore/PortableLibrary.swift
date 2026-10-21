import Foundation

extension LibraryStore {
    /// Publishes only managed content, never local registrations, live runtime directories, caches or game inputs.
    @discardableResult public func publish(_ id: UUID, to folder: URL, includeSaveSnapshots: Bool = false) throws -> URL {
        try locked {
            try reload(); let env = try writable(id)
            let targetRoot = folder.resolvingSymlinksInPath().path, localRoot = root.resolvingSymlinksInPath().path
            guard targetRoot != localRoot, !targetRoot.hasPrefix(localRoot + "/"), !localRoot.hasPrefix(targetRoot + "/") else { throw StudioError.invalid("Choose a portable folder separate from the working workspace.") }
            let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else { throw StudioError.invalid("Portable folder unavailable. Choose a downloaded local folder.") }
            let publication = UUID(), stage = folder.appendingPathComponent(".partial-\(UUID().uuidString)")
            try SafeFiles.directory(stage)
            defer { try? SafeFiles.fm.removeItem(at: stage) }
            let payload = stage.appendingPathComponent("payload"); try SafeFiles.directory(payload)
            var snapshots = state.snapshots.filter { $0.environment.id == id }
            let ids = Set(env.enabledMods + snapshots.flatMap { $0.environment.enabledMods })
            let mods = state.mods.filter { ids.contains($0.id) }
            for mod in mods {
                try SafeFiles.verify(packageURL(mod.id), mod.files)
                let source = try packageURL(mod.id).deletingLastPathComponent()
                if let hash = mod.originalArchiveHash {
                    guard try SafeFiles.hashFile(source.appendingPathComponent("original.zip")) == hash else { throw StudioError.invalid("Original archive checksum mismatch.") }
                }
                try SafeFiles.copyTree(source, payload.appendingPathComponent("packages/\(mod.id)"))
            }
            var copied = Set<UUID>()
            for revision in [env] + snapshots.map(\.environment) where copied.insert(revision.revision).inserted {
                let target = payload.appendingPathComponent("revisions/\(revision.revision.uuidString)")
                try SafeFiles.copyTree(revisionURL(revision), target)
                if !includeSaveSnapshots {
                    let saves = target.appendingPathComponent("saves")
                    if SafeFiles.fm.fileExists(atPath: saves.path) { try SafeFiles.fm.removeItem(at: saves) }
                }
            }
            for index in snapshots.indices {
                let original = snapshots[index]
                try SafeFiles.verify(revisionURL(original.environment), original.manifest)
                snapshots[index].manifest = try SafeFiles.regularFiles(payload.appendingPathComponent("revisions/\(original.environment.revision.uuidString)"))
            }
            var manifest = PortableManifest(environment: env, mods: mods, snapshots: snapshots, files: try SafeFiles.regularFiles(payload))
            manifest.publication = publication
            let encoded = try SafeFiles.encode(manifest)
            try encoded.write(to: stage.appendingPathComponent("manifest.json"), options: .withoutOverwriting)
            try Data(SafeFiles.hash(encoded).utf8).write(to: stage.appendingPathComponent("COMPLETE"), options: .withoutOverwriting)
            let destination = folder.appendingPathComponent("\(publication.uuidString).zmslibrary")
            try SafeFiles.fm.moveItem(at: stage, to: destination)
            return destination
        }
    }
    @discardableResult public func pull(from publication: URL) throws -> Adventure {
        try locked {
            try reload()
            guard publication.pathExtension == "zmslibrary" else { throw StudioError.invalid("Select a complete .zmslibrary publication.") }
            _ = try SafeFiles.regularFiles(publication)
            let data = try Data(contentsOf: publication.appendingPathComponent("manifest.json"))
            guard data.count <= 16_777_216, try String(contentsOf: publication.appendingPathComponent("COMPLETE"), encoding: .utf8) == SafeFiles.hash(data) else { throw StudioError.invalid("Publication is incomplete or its manifest checksum is invalid. Wait for sync/download.") }
            let manifest = try SafeFiles.decode(PortableManifest.self, data)
            guard manifest.schema == 1 else { throw StudioError.invalid("Unsupported portable schema.") }
            for path in manifest.files.keys { try SafeFiles.safePath(path) }
            var incoming = LibraryState(); incoming.environments = [manifest.environment]; incoming.mods = manifest.mods; incoming.snapshots = manifest.snapshots
            try Self.validate(incoming)
            guard manifest.snapshots.allSatisfy({ $0.environment.id == manifest.environment.id }) else { throw StudioError.invalid("Publication contains unrelated snapshot identities.") }
            let payload = publication.appendingPathComponent("payload")
            try SafeFiles.verify(payload, manifest.files)
            // Copy into our own staging area and reverify to avoid a changing file-provider source.
            let stage = root.appendingPathComponent("staging/\(UUID().uuidString)")
            defer { try? SafeFiles.fm.removeItem(at: stage) }
            try SafeFiles.copyTree(payload, stage); try SafeFiles.verify(stage, manifest.files)
            var next = state
            for mod in manifest.mods {
                let source = stage.appendingPathComponent("packages/\(mod.id)")
                try SafeFiles.verify(source.appendingPathComponent("content"), mod.files)
                if let hash = mod.originalArchiveHash { guard try SafeFiles.hashFile(source.appendingPathComponent("original.zip")) == hash else { throw StudioError.invalid("Imported original archive checksum mismatch.") } }
                if next.mods.contains(where: { $0.id == mod.id }) { try SafeFiles.verify(packageURL(mod.id), mod.files) }
                else {
                    let dest = root.appendingPathComponent("packages/\(mod.id)")
                    if SafeFiles.fm.fileExists(atPath: dest.path) { try SafeFiles.verify(dest.appendingPathComponent("content"), mod.files) }
                    else { try SafeFiles.copyTree(source, dest) }
                    next.mods.append(mod)
                }
            }
            var env = manifest.environment
            if state.environments.contains(where: { $0.id == env.id }) {
                env.parentID = env.id; env.id = UUID(); env.name = String(env.name.prefix(100)) + " (imported branch)"
            }
            env.trashed = false; env.gameplayVerified = false
            var revisions: [UUID: UUID] = [:]
            for original in [manifest.environment] + manifest.snapshots.map(\.environment) where revisions[original.revision] == nil {
                let source = stage.appendingPathComponent("revisions/\(original.revision.uuidString)")
                var target = env; target.revision = UUID(); revisions[original.revision] = target.revision
                try SafeFiles.copyTree(source, revisionURL(target))
                try SafeFiles.directory(savesURL(target)); try SafeFiles.directory(overlayURL(target))
            }
            env.revision = revisions[manifest.environment.revision]!
            for original in manifest.snapshots {
                var snap = original; snap.id = UUID(); snap.environment.id = env.id
                snap.environment.revision = revisions[original.environment.revision]!
                try SafeFiles.verify(revisionURL(snap.environment), snap.manifest)
                next.snapshots.append(snap)
            }
            next.environments.append(env)
            try commit(next, event: "Portable publication verified and imported. Existing branches preserved; local runtime setup still required.")
            return env
        }
    }
}
