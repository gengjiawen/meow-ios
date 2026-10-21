import SwiftUI

/// Utility > Paw Print (`LogbookModel`): the engine's record of notable
/// events, newest first under day headers. Each entry leads with its event,
/// drawn by kind and tinted by how it went; a tap shows its times and the
/// details the engine recorded.
struct LogbookView: View {
    @State private var model: LogbookModel

    init(model: LogbookModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Group {
            if let error = model.error, model.entries.isEmpty {
                ContentUnavailableView(
                    "utility.nav.pawPrint",
                    systemImage: "exclamationmark.triangle",
                    description: Text("logbook.readFailed \(error)"),
                )
            } else if model.loaded, model.entries.isEmpty {
                ContentUnavailableView(
                    "logbook.empty",
                    systemImage: "pawprint",
                    description: Text("logbook.emptyHint"),
                )
                .accessibilityIdentifier("logbook.empty")
            } else {
                entryList
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("utility.nav.pawPrint")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.run() }
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(model.entries.enumerated()), id: \.element.id) { index, entry in
                    // A day header above the first entry of each day.
                    if index == 0 || !Calendar.current.isDate(
                        entry.time,
                        inSameDayAs: model.entries[index - 1].time,
                    ) {
                        Text(entry.time.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.mutedText)
                            .textCase(.uppercase)
                            .padding(.leading, 4)
                            .padding(.top, index == 0 ? 0 : 8)
                    }
                    LogbookEntryCard(entry: entry)
                        .onAppear {
                            if entry.id == model.entries.last?.id {
                                Task { await model.loadMore() }
                            }
                        }
                }
            }
            .padding(16)
            .readableColumn()
        }
        .scrollContentBackground(.hidden)
    }
}

/// One entry: what happened, to what, and when; a tap shows the rest.
private struct LogbookEntryCard: View {
    let entry: LogbookEntry

    @State private var expanded = false

    private var tint: Color {
        switch entry.level {
        case .info: AppTheme.accent
        case .warning: AppTheme.warning
        case .error: AppTheme.danger
        }
    }

    var body: some View {
        GlassCard {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: LogbookKinds.icon(of: entry))
                        .font(.subheadline)
                        .foregroundStyle(tint)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        header
                        Text(entry.message)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(expanded ? nil : 3)
                            .multilineTextAlignment(.leading)
                        if expanded {
                            details
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .accessibilityIdentifier("logbook.entry")
    }

    /// "Dialer Proxy Switch · US Home", then the repeats and the time.
    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                Text(LogbookKinds.name(of: entry.kind))
                    .foregroundStyle(tint)
                    .fontWeight(.semibold)
                if let subject = entry.subject {
                    Text(verbatim: " · \(subject)")
                        .foregroundStyle(AppTheme.mutedText)
                }
            }
            .font(.caption)
            .lineLimit(1)
            Spacer(minLength: 8)
            Text((entry.count > 1 ? "×\(entry.count)  " : "") + entry.time.formatted(date: .omitted, time: .shortened))
                .font(.caption.monospacedDigit())
                .foregroundStyle(AppTheme.mutedText)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("logbook.first \(entry.time.formatted(date: .abbreviated, time: .standard))")
            if let last = entry.last {
                Text("logbook.last \(last.formatted(date: .abbreviated, time: .standard))")
            }
            ForEach((entry.fields ?? [:]).sorted { $0.key < $1.key }, id: \.key) { field in
                Text(verbatim: "\(field.key): \(field.value.text)")
            }
        }
        .font(.caption.monospaced())
        .foregroundStyle(AppTheme.mutedText)
        .padding(.top, 4)
    }
}

/// How the page names and draws the engine's event kinds
/// (`meow_common::logbook::kind`). A kind is never renamed once released, so
/// the table only grows; one it lacks (a newer engine's) shows its raw name
/// under its level's icon.
enum LogbookKinds {
    private static let all: [String: (name: LocalizedStringResource, icon: String)] = [
        "engine.start": ("logbook.kind.engineStart", "play.circle.fill"),
        "engine.stop": ("logbook.kind.engineStop", "stop.circle.fill"),
        "engine.unclean-exit": ("logbook.kind.engineUncleanExit", "exclamationmark.octagon.fill"),
        "config.reload": ("logbook.kind.configReload", "arrow.triangle.2.circlepath"),
        "config.change": ("logbook.kind.configChange", "slider.horizontal.3"),
        "subscription.update": ("logbook.kind.subscriptionUpdate", "icloud.and.arrow.down"),
        "proxy-provider.update": ("logbook.kind.proxyProviderUpdate", "point.3.connected.trianglepath.dotted"),
        "rule-provider.update": ("logbook.kind.ruleProviderUpdate", "list.bullet"),
        "geodata.update": ("logbook.kind.geodataUpdate", "globe"),
        "dialer-proxy.switch": ("logbook.kind.dialerProxySwitch", "arrow.left.arrow.right"),
        "dialer-proxy.check": ("logbook.kind.dialerProxyCheck", "checkmark.shield"),
        "network.interface": ("logbook.kind.networkInterface", "network"),
        "listener.start": ("logbook.kind.listenerStart", "antenna.radiowaves.left.and.right"),
        "logbook.cleared": ("logbook.kind.logbookCleared", "trash"),
        "logbook.reset": ("logbook.kind.logbookReset", "arrow.counterclockwise"),
    ]

    static func name(of kind: String) -> String {
        all[kind].map { String(localized: $0.name) } ?? kind
    }

    static func icon(of entry: LogbookEntry) -> String {
        if let known = all[entry.kind] {
            return known.icon
        }
        return switch entry.level {
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }
}
