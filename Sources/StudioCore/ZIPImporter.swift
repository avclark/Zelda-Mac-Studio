import Foundation
import CZip

/// Deliberately limited ZIP support: stored/deflate, UTF-8 names, single disk, no encryption or ZIP64.
public struct ZIPImporter {
    public var maxExpanded = 1_073_741_824
    public var maxFile = 134_217_728
    public var maxEntries = 20_000
    public var maxArchive = 268_435_456
    public init() {}
    public func extract(_ source: URL, to destination: URL) throws {
        let attrs = try source.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey, .isRegularFileKey])
        guard attrs.isRegularFile == true, attrs.isSymbolicLink != true, (attrs.fileSize ?? Int.max) <= maxArchive else { throw StudioError.invalid("ZIP exceeds the archive limit or is not a regular file.") }
        let data = try Data(contentsOf: source)
        guard data.count >= 22, data.count <= maxArchive else { throw StudioError.invalid("Invalid or oversized ZIP.") }
        func u16(_ i: Int) throws -> Int {
            guard i >= 0, i + 2 <= data.count else { throw StudioError.invalid("Truncated ZIP.") }
            return Int(data[i]) | Int(data[i+1]) << 8
        }
        func u32(_ i: Int) throws -> Int { try u16(i) | u16(i+2) << 16 }
        var end: Int?
        for i in stride(from: data.count - 22, through: max(0, data.count - 65557), by: -1) {
            if try u32(i) == 0x06054b50, try i + 22 + u16(i+20) == data.count { end = i; break }
        }
        guard let end, try u16(end+4) == 0, try u16(end+6) == 0, try u16(end+8) == u16(end+10) else { throw StudioError.invalid("Unsupported or incomplete ZIP.") }
        let count = try u16(end+10), centralSize = try u32(end+12), centralStart = try u32(end+16)
        guard count > 0, count <= maxEntries, count != 65535, centralStart + centralSize == end else { throw StudioError.invalid("ZIP directory or entry limit invalid; ZIP64 is unsupported.") }
        var cursor = centralStart, expanded = 0, seen = Set<String>(), ranges: [Range<Int>] = []
        try SafeFiles.directory(destination)
        for _ in 0..<count {
            guard try u32(cursor) == 0x02014b50 else { throw StudioError.invalid("Invalid ZIP directory.") }
            let flags = try u16(cursor+8), method = try u16(cursor+10), crc = try u32(cursor+16)
            let compressed = try u32(cursor+20), size = try u32(cursor+24)
            let nameLen = try u16(cursor+28), extraLen = try u16(cursor+30), commentLen = try u16(cursor+32)
            let attributes = try u32(cursor+38), local = try u32(cursor+42)
            let unixType = (attributes >> 16) & 0xf000
            let next = cursor + 46 + nameLen + extraLen + commentLen
            guard next <= end, flags & ~0x080e == 0, flags & 1 == 0, [0,8].contains(method),
                  try u16(cursor+34) == 0, size <= maxFile, compressed <= maxArchive,
                  [0, 0x8000, 0x4000].contains(unixType),
                  let rawName = String(data: data[(cursor+46)..<(cursor+46+nameLen)], encoding: .utf8) else { throw StudioError.invalid("Unsupported ZIP entry, link, encryption or size limit.") }
            let isDirectory = rawName.hasSuffix("/")
            let name = isDirectory ? String(rawName.dropLast()) : rawName
            try SafeFiles.safePath(name); try SafeFiles.rejectPrivateInput(name)
            guard seen.insert(name.precomposedStringWithCanonicalMapping.lowercased()).inserted else { throw StudioError.invalid("Duplicate or case-colliding ZIP paths.") }
            expanded += size
            guard expanded <= maxExpanded else { throw StudioError.invalid("ZIP expanded size limit exceeded.") }
            guard try u32(local) == 0x04034b50, try u16(local+6) == flags, try u16(local+8) == method else { throw StudioError.invalid("ZIP local header mismatch.") }
            let localNameLen = try u16(local+26), localExtraLen = try u16(local+28)
            let start = local + 30 + localNameLen + localExtraLen, stop = start + compressed
            guard local >= 0, start <= centralStart, stop <= centralStart,
                  String(data: data[(local+30)..<(local+30+localNameLen)], encoding: .utf8) == rawName,
                  !ranges.contains(where: { $0.overlaps(local..<stop) }) else { throw StudioError.invalid("ZIP entry overlaps or has mismatched paths.") }
            ranges.append(local..<stop)
            if flags & 8 == 0 {
                guard try u32(local+14) == crc, try u32(local+18) == compressed, try u32(local+22) == size else { throw StudioError.invalid("ZIP size or CRC headers disagree.") }
            }
            let target = destination.appendingPathComponent(name)
            if isDirectory {
                guard size == 0, unixType != 0x8000 else { throw StudioError.invalid("Malformed ZIP directory.") }
                try SafeFiles.directory(target)
            } else {
                guard unixType != 0x4000 else { throw StudioError.invalid("Ambiguous ZIP directory.") }
                let input = Data(data[start..<stop]); var output: Data
                if method == 0 { guard compressed == size else { throw StudioError.invalid("Stored ZIP size mismatch.") }; output = input }
                else {
                    output = Data(count: max(1, size))
                    let ok = output.withUnsafeMutableBytes { out in input.withUnsafeBytes { src in
                        zms_inflate(src.bindMemory(to: UInt8.self).baseAddress, input.count, out.bindMemory(to: UInt8.self).baseAddress, size)
                    } }
                    guard ok == 1 else { throw StudioError.invalid("ZIP decompression failed or exceeded declared size.") }
                    if size == 0 { output = Data() }
                }
                let actualCRC = output.withUnsafeBytes { zms_crc($0.bindMemory(to: UInt8.self).baseAddress, output.count) }
                guard actualCRC == UInt32(crc) else { throw StudioError.invalid("ZIP CRC checksum mismatch.") }
                try SafeFiles.directory(target.deletingLastPathComponent())
                try output.write(to: target, options: .withoutOverwriting)
            }
            cursor = next
        }
        guard cursor == end else { throw StudioError.invalid("Unexpected ZIP directory data.") }
        _ = try SafeFiles.regularFiles(destination, maxBytes: maxExpanded, maxFiles: maxEntries * 2)
    }
}
