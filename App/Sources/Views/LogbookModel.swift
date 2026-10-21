import Foundation
import MeowModels
import Observation

/// How an event went.
enum LogbookLevel: String, Decodable, Sendable {
    case info, warning, error
}

/// One logbook entry, as `meow_logbook_read` serves it.
struct LogbookEntry: Decodable, Equatable, Identifiable, Sendable {
    /// Identity and order: newest first.
    let id: UInt64
    /// First occurrence.
    let time: Date
    /// Latest occurrence, once a repeat was folded in.
    let last: Date?
    /// Occurrences folded into this entry.
    let count: UInt32
    let kind: String
    let level: LogbookLevel
    /// What the event is about: a group, provider or listener name.
    let subject: String?
    /// One English sentence; for a folded entry, the latest occurrence's.
    let message: String
    let fields: [String: LogbookField]?
}

/// A recorded field's value, as text.
struct LogbookField: Decodable, Equatable, Sendable {
    let text: String

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let string = try? value.decode(String.self) {
            text = string
        } else if let number = try? value.decode(Int64.self) {
            text = String(number)
        } else if let number = try? value.decode(Double.self) {
            text = String(number)
        } else if let flag = try? value.decode(Bool.self) {
            text = String(flag)
        } else if let list = try? value.decode([LogbookField].self) {
            text = list.map(\.text).joined(separator: ", ")
        } else {
            text = "…"
        }
    }
}

/// A page of the logbook, newest first.
struct LogbookPage: Sendable {
    var entries: [LogbookEntry] = []
    /// The latest write: pass it as `since` to ask whether anything followed.
    var rev: UInt64 = 0
    /// Older entries exist past this page.
    var more = false
}

struct LogbookReadError: Error, Sendable {
    let message: String
}

/// Reads the engine's logbook from the App Group (`meow_logbook_read`) in
/// this process, so the page also opens while the VPN is down.
enum LogbookReader {
    static func read(
        before: UInt64 = 0,
        since: UInt64 = 0,
        limit: Int = 0,
        in dir: URL = AppGroup.meowConfigDir,
    ) async throws -> LogbookPage {
        let home = dir.path(percentEncoded: false)
        let json = await Task.detached(priority: .utility) {
            answer(home: home, before: before, since: since, limit: limit)
        }.value
        return try decode(json)
    }

    static func decode(_ json: String) throws -> LogbookPage {
        struct Answer: Decodable {
            var entries: [LogbookEntry]?
            var rev: UInt64?
            var more: Bool?
            var error: String?
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = parseTime(text) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "not an RFC 3339 time: \(text)",
                ))
            }
            return date
        }
        let answer: Answer
        do {
            answer = try decoder.decode(Answer.self, from: Data(json.utf8))
        } catch {
            throw LogbookReadError(message: error.localizedDescription)
        }
        if let error = answer.error {
            throw LogbookReadError(message: error)
        }
        return LogbookPage(entries: answer.entries ?? [], rev: answer.rev ?? 0, more: answer.more ?? false)
    }

    /// RFC 3339, with milliseconds unless they are zero.
    private static func parseTime(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) {
            return date
        }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: text)
    }

    private static func answer(home: String, before: UInt64, since: UInt64, limit: Int) -> String {
        let raw: UnsafeMutablePointer<CChar>? = home.withCString {
            meow_logbook_read($0, Int64(clamping: before), Int64(clamping: since), Int32(clamping: limit), nil, nil)
        }
        guard let raw else { return "{}" }
        defer { meow_string_free(raw) }
        return String(cString: raw)
    }
}

/// Utility > Paw Print: the engine's logbook, newest first. Polls every 2 s
/// while shown with a one-entry probe, and re-reads only once something was
/// written; older pages load on scroll.
@MainActor
@Observable
final class LogbookModel {
    static let pollInterval: Duration = .seconds(2)
    static let pageSize = 100

    private(set) var entries: [LogbookEntry] = []
    private(set) var more = false
    /// Whether the first read answered, so the page can tell "nothing yet"
    /// from "not read yet".
    private(set) var loaded = false
    private(set) var error: String?

    @ObservationIgnored private var rev: UInt64 = 0
    @ObservationIgnored private var loadingMore = false
    @ObservationIgnored private let read: @Sendable (_ before: UInt64, _ since: UInt64, _ limit: Int) async throws
        -> LogbookPage

    init(read: @escaping @Sendable (_ before: UInt64, _ since: UInt64, _ limit: Int) async throws -> LogbookPage) {
        self.read = read
    }

    convenience init() {
        self.init { before, since, limit in
            try await LogbookReader.read(before: before, since: since, limit: limit)
        }
    }

    /// Reads, then polls until cancelled.
    func run() async {
        await reload()
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.pollInterval)
            guard !Task.isCancelled else { break }
            await poll()
        }
    }

    /// Re-reads as many of the newest entries as are shown.
    func reload() async {
        do {
            let page = try await read(0, 0, max(Self.pageSize, entries.count))
            entries = page.entries
            more = page.more
            rev = page.rev
            error = nil
        } catch let failure as LogbookReadError {
            error = failure.message
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }

    /// A one-entry read answers with the latest write; re-read once it moved.
    func poll() async {
        guard let probe = try? await read(0, rev, 1) else { return }
        if probe.rev != rev || error != nil {
            await reload()
        }
    }

    /// The page before the oldest entry shown.
    func loadMore() async {
        guard more, !loadingMore, let oldest = entries.last else { return }
        loadingMore = true
        defer { loadingMore = false }
        guard let page = try? await read(oldest.id, 0, Self.pageSize) else { return }
        // A reload while this read ran may have replaced the list.
        guard entries.last?.id == oldest.id else { return }
        entries += page.entries
        more = page.more
    }
}
