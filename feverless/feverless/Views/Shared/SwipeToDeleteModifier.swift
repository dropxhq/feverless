import SwiftUI

// MARK: - SwipeToDeleteModifier
// Custom swipe-to-delete for use outside of List (e.g. inside ScrollView/VStack).
// Two-stage confirmation: first tap shows "确认", second tap deletes.
// Right swipe, tap on row content, or entering multi-select all reset the row.

struct SwipeToDeleteModifier: ViewModifier {
    @State private var offset: CGFloat = 0
    @State private var isConfirming: Bool = false
    @State private var isDragging: Bool = false
    @State private var dragBaseOffset: CGFloat = 0
    let isActive: Bool       // set false in multi-select mode
    let deleteButtonWidth: CGFloat
    let onDelete: () -> Void

    init(isActive: Bool, deleteButtonWidth: CGFloat = 80, onDelete: @escaping () -> Void) {
        self.isActive = isActive
        self.deleteButtonWidth = deleteButtonWidth
        self.onDelete = onDelete
    }

    private var isOpen: Bool { offset < -8 }

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            // Layer 1 (bottom): full-width tap-to-close background, only when open
            if isOpen {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { closeRow() }
            }

            // Layer 2: red delete / confirm button (trailing)
            if offset < 0 {
                (isConfirming ? Color(red: 0.75, green: 0.1, blue: 0.1) : Color.red)
                    .frame(width: min(-offset, deleteButtonWidth))
                    .overlay(
                        VStack(spacing: 2) {
                            Image(systemName: isConfirming ? "checkmark" : "trash")
                                .font(.system(size: 15))
                            Text(isConfirming ? "确认" : "删除")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .opacity(-offset > 24 ? 1 : 0)
                    )
                    .onTapGesture {
                        if isConfirming {
                            onDelete()
                            closeRow()
                        } else {
                            withAnimation(.spring(duration: 0.2)) {
                                isConfirming = true
                            }
                        }
                    }
            }

            // Layer 3 (top): content — passes through taps when open so layers below can respond
            content
                .offset(x: offset)
                .allowsHitTesting(!isOpen)
        }
        .clipped()
        .simultaneousGesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    guard isActive else { return }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > abs(dy) * 0.7 else { return }
                    if !isDragging {
                        isDragging = true
                        dragBaseOffset = offset
                        // Any new drag resets confirming state
                        isConfirming = false
                    }
                    let newOffset = dragBaseOffset + dx
                    withAnimation(.interactiveSpring()) {
                        offset = min(0, max(newOffset, -deleteButtonWidth))
                    }
                }
                .onEnded { _ in
                    guard isActive else { return }
                    isDragging = false
                    if offset > -(deleteButtonWidth * 0.5) {
                        closeRow()
                    } else {
                        withAnimation(.spring(duration: 0.25)) { offset = -deleteButtonWidth }
                    }
                }
        )
        .onChange(of: isActive) { _, newValue in
            if !newValue { closeRow() }
        }
    }

    private func closeRow() {
        withAnimation(.spring(duration: 0.25)) {
            offset = 0
            isConfirming = false
        }
    }
}

extension View {
    func swipeToDelete(isActive: Bool, onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDeleteModifier(isActive: isActive, onDelete: onDelete))
    }
}
