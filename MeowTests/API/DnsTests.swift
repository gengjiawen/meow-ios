import Foundation
@testable import meow_ios
import Testing

/// Contract for the DNS results endpoint consumed by `DnsView`.
@Suite("MeowAPI DNS results endpoint", .tags(.api))
struct DnsTests {
    private static func _contractAnchor(api: MeowAPI) async throws {
        _ = DnsResult.self
        _ = try await api.getDnsResults()
        _ = try await api.getDnsResults(search: "example.com", limit: 64)
    }

    @Test
    func `mock transport returns decodable DNS results`() async throws {
        let api = MeowAPI()
        let results = try await api.getDnsResults()
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { !$0.name.isEmpty })
    }

    @Test
    func `mock transport filters DNS results by search`() async throws {
        let api = MeowAPI()
        let filtered = try await api.getDnsResults(search: "github")
        #expect(filtered.allSatisfy { $0.name.localizedCaseInsensitiveContains("github") })
    }
}
