import SwiftUI

struct NotesView: View {
    @Bindable var store: NotesStore
    @Bindable var model: NotchViewModel
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if store.text.isEmpty {
                Text("Type a note…")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $store.text)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .focused($focused)
                .padding(4)
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onChange(of: focused) { _, isFocused in
            model.setEditingText(isFocused)
        }
    }
}
