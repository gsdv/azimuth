import SwiftUI

struct RecentSendsView: View {
    @Environment(AzimuthEngine.self) private var engine

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
                            ForEach(settings.history) { record in
                                row(record)
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
                            settings.lastSentDate = nil
                        } label: {
                            Text("Clear")
                        }
                        .tint(Theme.danger)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "paperplane")
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
        HStack(spacing: 12) {
            Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.title3)
                .foregroundStyle(record.success ? Theme.success : Theme.danger)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.semibold))
                Text(detail(for: record))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
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
