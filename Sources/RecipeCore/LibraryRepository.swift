import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// A previous copy plus atomic replacement protects interrupted saves. An exclusive lock and
/// original-byte comparison prevent two instances of this app from silently losing updates.
public final class LibraryRepository {
    public let url: URL
    private var expectedBytes: Data?
    private var loaded = false
    public init(url: URL) { self.url = url }

    public func load() throws -> RecipeDocument {
        loaded = false
        return try withLock {
            let bytes = try readCurrent()
            let document = try bytes.map { try RecipeDocument(data: $0) } ?? RecipeDocument()
            expectedBytes = bytes
            loaded = true
            return document
        }
    }

    public func save(_ document: RecipeDocument) throws {
        guard loaded else { throw LibraryError.invalid("load the library successfully before saving") }
        let data = try document.encoded()
        try withLock {
            guard try readCurrent() == expectedBytes else { throw LibraryError.conflict }
            if let previous = expectedBytes {
                try previous.write(to: url.appendingPathExtension("previous"), options: .atomic)
            }
            try data.write(to: url, options: .atomic)
            expectedBytes = data
        }
    }

    private func readCurrent() throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? 0 <= RecipeDocument.maximumBytes else {
            throw LibraryError.tooLarge
        }
        return try Data(contentsOf: url)
    }

    private func withLock<T>(_ operation: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let lock = url.appendingPathExtension("lock")
        let fd = open(lock.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw POSIXError(.EACCES) }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw LibraryError.conflict }
        defer { flock(fd, LOCK_UN) }
        return try operation()
    }
}
