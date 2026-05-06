import SwiftUI

struct SchedulePicker: View {
    @Binding var schedule: SendSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            chipsGrid
            if schedule.kind == .daily || schedule.kind == .weekly {
                detailControls
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: schedule)
    }

    private var chipsGrid: some View {
        HStack(spacing: 6) {
            chip(.hourly)
            chip(.every6Hours)
            chip(.every12Hours)
            chip(.daily)
            chip(.weekly)
        }
    }

    @ViewBuilder
    private var detailControls: some View {
        VStack(spacing: 10) {
            if schedule.kind == .weekly {
                row(label: "On") {
                    Picker("Day", selection: weekdayBinding) {
                        ForEach(1...7, id: \.self) { wd in
                            Text(SendSchedule.weekdayName(wd)).tag(wd)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.skyDeep)
                    .labelsHidden()
                }
            }
            row(label: "At") {
                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Theme.skyDeep)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.chipFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.cardStroke, lineWidth: 0.5)
                )
        )
    }

    private func row<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            Spacer()
            content()
        }
    }

    private func chip(for kind: SendSchedule.Kind) -> SendSchedule {
        switch kind {
        case .hourly:       return .hourly
        case .every6Hours:  return .every6Hours
        case .every12Hours: return .every12Hours
        case .daily:
            let h = schedule.hour ?? SendSchedule.defaultDailyHour
            let m = schedule.minute ?? SendSchedule.defaultDailyMinute
            return .dailyAt(hour: h, minute: m)
        case .weekly:
            let wd = schedule.weekday ?? SendSchedule.defaultWeeklyWeekday
            let h = schedule.hour ?? SendSchedule.defaultDailyHour
            let m = schedule.minute ?? SendSchedule.defaultDailyMinute
            return .weeklyOn(weekday: wd, hour: h, minute: m)
        }
    }

    private func chip(_ kind: SendSchedule.Kind) -> some View {
        let selected = kind == schedule.kind
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            schedule = chip(for: kind)
        } label: {
            Text(kind.shortLabel)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(selected ? .white : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(selected ? AnyShapeStyle(Theme.pulseGradient) : AnyShapeStyle(Theme.chipFill))
                )
                .overlay(
                    Capsule().stroke(selected ? Color.clear : Theme.cardStroke, lineWidth: 0.7)
                )
                .shadow(color: selected ? Theme.sky.opacity(0.4) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                let h = schedule.hour ?? SendSchedule.defaultDailyHour
                let m = schedule.minute ?? SendSchedule.defaultDailyMinute
                var components = DateComponents()
                components.hour = h
                components.minute = m
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let h = Calendar.current.component(.hour, from: newDate)
                let m = Calendar.current.component(.minute, from: newDate)
                switch schedule {
                case .dailyAt:
                    schedule = .dailyAt(hour: h, minute: m)
                case .weeklyOn(let wd, _, _):
                    schedule = .weeklyOn(weekday: wd, hour: h, minute: m)
                default:
                    break
                }
            }
        )
    }

    private var weekdayBinding: Binding<Int> {
        Binding(
            get: { schedule.weekday ?? SendSchedule.defaultWeeklyWeekday },
            set: { newWd in
                let h = schedule.hour ?? SendSchedule.defaultDailyHour
                let m = schedule.minute ?? SendSchedule.defaultDailyMinute
                schedule = .weeklyOn(weekday: newWd, hour: h, minute: m)
            }
        )
    }
}
