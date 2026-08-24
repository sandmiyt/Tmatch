import SwiftUI
import UIKit

enum QuestionMediaLayout: Equatable {
    case standard
    case compact

    var singleHeight: CGFloat { self == .standard ? 228 : 132 }
    var multipleSize: CGSize { self == .standard ? CGSize(width: 220, height: 165) : CGSize(width: 164, height: 116) }
    var cornerRadius: CGFloat { self == .standard ? 16 : 12 }
    var imagePadding: CGFloat { self == .standard ? 10 : 7 }
}

struct QuestionMediaStrip: View {
    let urls: [String]
    var layout: QuestionMediaLayout = .standard
    @State private var selected: SelectedMedia?

    private var values: [String] {
        var seen = Set<String>()
        return urls.compactMap { raw in
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert(value).inserted else { return nil }
            return value
        }
    }

    @ViewBuilder
    var body: some View {
        if values.count == 1, let value = values.first {
            mediaButton(value)
                .frame(maxWidth: .infinity)
                .frame(height: layout.singleHeight)
                .fullScreenCover(item: $selected) { item in
                    QuestionMediaPreview(item: item)
                }
        } else if !values.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(values, id: \.self) { value in
                        mediaButton(value)
                            .frame(width: layout.multipleSize.width, height: layout.multipleSize.height)
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

    private func mediaButton(_ value: String) -> some View {
        Button {
            Haptics.selection()
            selected = SelectedMedia(value: value)
        } label: {
            QuestionMediaImage(value: value)
                .padding(layout.imagePadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.7)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看题目图片")
        .accessibilityHint("轻点可全屏查看并缩放")
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
