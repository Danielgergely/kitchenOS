//
//  DayColumnChrome.swift
//  KitchenOS
//
//  The pieces the private ("My Plan") and shared day columns draw identically:
//  the date header, the dashed "add a breakfast/snack" button, and the small
//  corner button on a meal card. They were copy-pasted between DayColumn,
//  SharedDayColumn, MealSlotView and SharedMealSlotView.
//

import SwiftUI

/// Weekday + day number at the top of a column, with today highlighted.
struct DayColumnHeader: View {
    let date: Date

    var body: some View {
        VStack {
            Text(date.formatted("EEE"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(date.formatted("d"))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Calendar.current.isDateInToday(date) ? .blue : .primary)
        }
        .padding(.bottom, 8)
    }
}

/// The dashed placeholder shown for collapsible, empty slots (breakfast / snack).
struct CollapsedSlotButton: View {
    let type: MealType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                Text(type.rawValue.capitalized)
            }
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.tertiary.opacity(0.5))
            )
        }
    }
}

/// Top-right control on a meal card: delete when the slot is filled, otherwise a
/// chevron that collapses an expanded-but-empty slot.
struct SlotCornerButton: View {
    let hasMeal: Bool
    let expandUp: Bool
    let onDelete: () -> Void
    let onCloseEmpty: (() -> Void)?

    var body: some View {
        if hasMeal {
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.red)
                    .frame(width: 28, height: 28)
            }
            .padding(4)
        } else if let onCloseEmpty {
            Button(action: onCloseEmpty) {
                Image(systemName: expandUp ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(6)
        }
    }
}
