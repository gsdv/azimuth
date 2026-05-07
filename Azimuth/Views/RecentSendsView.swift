import SwiftUI

struct RecentSendsView: View {
    @Environment(AzimuthEngine.self) private var engine

    @State private var filterEndpointID: UUID?
    @State private var chipScroll = ChipScrollState()
    @State private var detailRecord: SendRecord?

    var body: some View {
        @Bindable var settings = engine.settings

        NavigationStack {
            ZStack {
                CanvasBackground()

                if settings.history.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            if settings.endpoints.count > 1 {
                                filterChips(settings: settings)
                                    .padding(.bottom, 4)
                            }
                            ForEach(filteredHistory(settings: settings)) { record in
                                Button {
                                    detailRecord = record
                                } label: {
                                    row(record)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Recent")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !settings.history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            settings.history = []
                        } label: {
                            Text("Clear")
                        }
                        .tint(Theme.danger)
                    }
                }
            }
            .sheet(item: $detailRecord) { record in
                SendDetailSheet(record: record)
            }
        }
    }

    private func filteredHistory(settings: AppSettings) -> [SendRecord] {
        guard let id = filterEndpointID else { return settings.history }
        return settings.history.filter { $0.endpointID == id }
    }

    private func filterChips(settings: AppSettings) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", isSelected: filterEndpointID == nil) {
                    filterEndpointID = nil
                }
                ForEach(settings.endpoints) { ep in
                    chip(label: ep.displayName, isSelected: filterEndpointID == ep.id) {
                        filterEndpointID = ep.id
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
        .onScrollGeometryChange(for: ChipScrollState.self) { geo in
            ChipScrollState(
                offset: geo.contentOffset.x,
                contentWidth: geo.contentSize.width,
                viewportWidth: geo.containerSize.width
            )
        } action: { _, new in
            withAnimation(.easeOut(duration: 0.15)) {
                chipScroll = new
            }
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: chipScroll.fadeLeading ? .clear : .black, location: 0.0),
                    .init(color: .black, location: 0.05),
                    .init(color: .black, location: 0.95),
                    .init(color: chipScroll.fadeTrailing ? .clear : .black, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? .white : Theme.skyDeep)
                .background(
                    Capsule()
                        .fill(isSelected ? AnyShapeStyle(Theme.pulseGradient) : AnyShapeStyle(Theme.chipFill))
                        .overlay(
                            Capsule().stroke(Theme.cardStroke, lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "location.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.sky)
            Text("No sends yet")
                .font(.system(.title3, design: .rounded).weight(.semibold))
            Text("Tap **Send now** on the Track tab to post a location, or wait for the next scheduled send.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
    }

    private func row(_ record: SendRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.title3)
                .foregroundStyle(record.success ? Theme.success : Theme.danger)
            VStack(alignment: .leading, spacing: 0) {
                Text(record.endpointName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                Text(detail(for: record))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.cardStroke, lineWidth: 0.7)
                )
                .shadow(color: Theme.skyDeep.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func detail(for record: SendRecord) -> String {
        if record.success, let code = record.statusCode {
            return "Sent · HTTP \(code)"
        }
        if let code = record.statusCode {
            return "HTTP \(code) · \(record.message ?? "Failed")"
        }
        return record.message ?? (record.success ? "Sent" : "Failed")
    }
}

private struct ChipScrollState: Equatable {
    var offset: CGFloat = 0
    var contentWidth: CGFloat = 0
    var viewportWidth: CGFloat = 0

    var fadeLeading: Bool { offset > 1 }
    var fadeTrailing: Bool {
        guard contentWidth > viewportWidth else { return false }
        return offset + viewportWidth < contentWidth - 1
    }
}

private struct SendDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let record: SendRecord

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        headerCard
                        if let message = record.message, !message.isEmpty {
                            messageCard(message)
                        }
                        if let json = record.bodyJSON, !json.isEmpty {
                            payloadCard(json: json, truncated: record.bodyTruncated)
                        } else {
                            payloadUnavailableCard
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Send detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var headerCard: some View {
        DetailCard(title: "Result", icon: record.success ? "checkmark.circle" : "xmark.octagon") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .font(.title2)
                    .foregroundStyle(record.success ? Theme.success : Theme.danger)
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.endpointName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(record.date.formatted(date: .complete, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let code = record.statusCode {
                        Text("HTTP \(code)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func messageCard(_ message: String) -> some View {
        DetailCard(title: record.success ? "Note" : "Error", icon: "text.alignleft") {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func payloadCard(json: String, truncated: Bool) -> some View {
        DetailCard(title: "Payload", icon: "curlybraces") {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(json)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(minWidth: 0, alignment: .topLeading)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(uiColor: .separator).opacity(0.6), lineWidth: 0.7)
                        )
                )
                if truncated {
                    Label("Payload exceeded 16 KB and was truncated.", systemImage: "scissors")
                        .font(.caption2)
                        .foregroundStyle(Theme.warning)
                }
            }
        }
    }

    private var payloadUnavailableCard: some View {
        DetailCard(title: "Payload", icon: "curlybraces") {
            Text("No payload was captured for this send.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DetailCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.skyDeep)
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.cardStroke, lineWidth: 0.7)
                )
                .shadow(color: Theme.skyDeep.opacity(0.08), radius: 14, x: 0, y: 6)
        )
    }
}
