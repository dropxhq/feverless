import SwiftUI

// MARK: - SwipeToDeleteModifier
// Custom swipe-to-delete for use outside of List (e.g. inside ScrollView/VStack).
// Each row gets its own drag offset via @State inside the modifier.

struct SwipeToDeleteModifier: ViewModifier {
    @State private var offset: CGFloat = 0
    let isActive: Bool       // set false in multi-select mode
    let deleteButtonWidth: CGFloat
    let onDelete: () -> Void

    init(isActive: Bool, deleteButtonWidth: CGFloat = 80, onDelete: @escaping () -> Void) {
        self.isActive = isActive
        self.deleteButtonWidth = deleteButtonWidth
        self.onDelete = onDelete
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            // Red delete region behind content
            if offset < 0 {
                Color.red
                    .frame(width: min(-offset, deleteButtonWidth))
                    .overlay(
                        VStack(spacing: 2) {
                            Image(systemName: "trash")
                                .font(.system(size: 15))
                            Text("删除")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .opacity(-offset > 24 ? 1 : 0)
                    )
                    .onTapGesture {
                        onDelete()
                        withAnimation(.spring(duration: 0.25)) { offset = 0 }
                    }
            }

            content
                .offset(x: offset)
        }
        .clipped()
        .simultaneousGesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    guard isActive else { return }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    // Only activate for predominantly horizontal (< ~54° from horizontal)
                    guard abs(dx) > abs(dy) * 0.7, dx < 0 else { return }
                    withAnimation(.interactiveSpring()) {
                        offset = max(dx, -deleteButtonWidth)
                    }
                }
                .onEnded { _ in
                    guard isActive else { return }
                    if offset <= -(deleteButtonWidth * 0.5) {
                        // Commit delete on release past half-way
                        onDelete()
                    }
                    withAnimation(.spring(duration: 0.25)) { offset = 0 }
                }
        )
        .onChange(of: isActive) { _, newValue in
            if !newValue {
                withAnimation(.spring(duration: 0.2)) { offset = 0 }
            }
        }
    }
}

extension View {
    func swipeToDelete(isActive: Bool, onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDeleteModifier(isActive: isActive, onDelete: onDelete))
    }
}
