import SwiftUI
import UIKit

struct QuestionMediaStrip: View {
    let urls: [String]
    @State private var selected: SelectedMedia?

    var body: some View {
        if !urls.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(urls, id: \.self) { value in
                        Button {
                            Haptics.selection()
                            selected = SelectedMedia(value: value)
                        } label: {
                            QuestionMediaImage(value: value)
                                .frame(maxWidth: 260, minHeight: 100, maxHeight: 220)
                                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("查看题目图片")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .fullScreenCover(item: $selected) { item in
                QuestionMediaPreview(item: item)
            }
        }
    }
}

private struct QuestionMediaImage: View {
    let value: String

    var body: some View {
        Group {
            if let image = decodedDataImage(value) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let url = APIClient.shared.assetURL(value) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        ContentUnavailableView("图片加载失败", systemImage: "photo.badge.exclamationmark")
                    default:
                        ProgressView()
                    }
                }
            } else {
                ContentUnavailableView("图片不可用", systemImage: "photo.badge.exclamationmark")
            }
        }
    }

    private func decodedDataImage(_ value: String) -> UIImage? {
        guard value.lowercased().hasPrefix("data:image/"),
              let comma = value.firstIndex(of: ",") else { return nil }
        let header = String(value[..<comma]).lowercased()
        let payload = String(value[value.index(after: comma)...])
        let data: Data?
        if header.contains(";base64") {
            data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters)
        } else {
            data = payload.removingPercentEncoding?.data(using: .utf8)
        }
        guard let data else { return nil }
        return UIImage(data: data)
    }
}

private struct QuestionMediaPreview: View {
    @Environment(\.dismiss) private var dismiss
    let item: SelectedMedia
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var liveScale: CGFloat = 1
    @GestureState private var liveOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                QuestionMediaImage(value: item.value)
                    .scaleEffect(clampedScale(scale * liveScale))
                    .offset(x: offset.width + liveOffset.width, y: offset.height + liveOffset.height)
                    .gesture(magnifyGesture.simultaneously(with: dragGesture))
                    .onTapGesture(count: 2) {
                        withAnimation(.snappy) {
                            if scale > 1.05 {
                                scale = 1
                                offset = .zero
                            } else {
                                scale = 2
                            }
                        }
                        Haptics.light()
                    }
                    .padding(18)
            }
            .navigationTitle("题目图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($liveScale) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                scale = clampedScale(scale * value.magnification)
                if scale <= 1.05 { offset = .zero }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($liveOffset) { value, state, _ in
                guard scale * liveScale > 1.05 else { return }
                state = value.translation
            }
            .onEnded { value in
                guard scale > 1.05 else {
                    offset = .zero
                    return
                }
                offset.width += value.translation.width
                offset.height += value.translation.height
            }
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), 4)
    }
}

private struct SelectedMedia: Identifiable {
    let value: String
    var id: String { value }
}
