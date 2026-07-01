import MeowModels
import SwiftUI

struct DnsView: View {
    @Environment(MeowAPI.self) private var api
    @State private var results: [DnsResult] = []
    @State private var query: String = ""
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(filtered) { result in
                row(for: result)
            }
        }
        .listStyle(.plain)
        .overlay {
            if results.isEmpty {
                ContentUnavailableView(
                    "dns.empty.title",
                    systemImage: "network",
                    description: Text("dns.empty.description"),
                )
                .accessibilityIdentifier("dns.emptyState")
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
                    .accessibilityIdentifier("dns.emptySearch")
            }
        }
        .safeAreaInset(edge: .top) {
            if let errorMessage {
                errorBanner(errorMessage)
            }
        }
        .searchable(text: $query)
        .navigationTitle(Text(
            "dns.nav.titleFormat \(displayCount)",
            comment: "DNS screen navigation title; %lld = result count",
        ))
        .navigationBarTitleDisplayMode(.inline)
        .task { await poll() }
    }

    private var displayCount: Int {
        filtered.count
    }

    private var filtered: [DnsResult] {
        guard !query.isEmpty else { return results }
        return results.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private func row(for result: DnsResult) -> some View {
        let slug = result.name.identifierSlug
        let ips = result.ips.joined(separator: ", ")
        let upstream = result.fromServer ?? String(localized: "dns.row.unknownUpstream")
        return GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.headline)
                    .lineLimit(2)
                    .accessibilityIdentifier("dns.row.\(slug).domain")
                Text(ips)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .accessibilityIdentifier("dns.row.\(slug).ips")
                HStack(spacing: 10) {
                    Label(upstream, systemImage: "server.rack")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("dns.row.\(slug).upstream")
                    Spacer()
                    Text("dns.row.ttl \(result.ttl)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("dns.row.\(slug).ttl")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("a11y.dns.row.label \(result.name) \(ips) \(upstream) \(result.ttl)"))
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityIdentifier("dns.row.\(slug)")
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warning)
                .accessibilityHidden(true)
            Text(message)
                .font(.caption)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("a11y.dns.errorBanner \(message)"))
        .accessibilityIdentifier("dns.errorBanner")
    }

    private func poll() async {
        while !Task.isCancelled {
            do {
                let fetched = try await api.getDnsResults()
                results = fetched
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            try? await Task.sleep(for: .seconds(2))
        }
    }
}
