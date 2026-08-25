import SwiftUI
import UIKit

enum QuestionMediaLayout: Equatable {
    case standard
    case compact

    var singleFigureSize: CGSize { self == .standard ? CGSize(width: 240, height: 150) : CGSize(width: 128, height: 84) }
    var multipleFigureSize: CGSize { self == .standard ? CGSize(width: 136, height: 94) : CGSize(width: 112, height: 74) }
    var formulaSize: CGSize { self == .standard ? CGSize(width: 164, height: 38) : CGSize(width: 116, height: 30) }
    var cornerRadius: CGFloat { self == .standard ? 16 : 12 }
    var imagePadding: CGFloat { self == .standard ? 8 : 5 }
}

struct QuestionMediaStrip: View {
    let urls: [String]
    var types: [String] = []
    var layout: QuestionMediaLayout = .standard
    @State private var selected: SelectedMedia?

    private var items: [QuestionMediaItem] {
        var seen = Set<String>()
        return urls.enumerated().compactMap { index, raw in
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert(value).inserted else { return nil }
            let declaredType = types.indices.contains(index) ? types[index] : ""
            return QuestionMediaItem(value: value, kind: mediaKind(value: value, declaredType: declaredType))
        }
    }

    private var formulas: [QuestionMediaItem] { items.filter { $0.kind == .formula } }
    private var figures: [QuestionMediaItem] { items.filter { $0.kind == .figure } }

    @ViewBuilder
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: layout == .standard ? 8 : 5) {
                if !formulas.isEmpty { formulaStrip }
                if !figures.isEmpty { figureStrip }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fullScreenCover(item: $selected) { item in
                QuestionMediaPreview(item: item)
            }
        }
    }

    private var formulaStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(formulas) { item in
                    mediaButton(item)
                        .frame(width: layout.formulaSize.width, height: layout.formulaSize.height)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var figureStrip: some View {
        if figures.count == 1, let item = figures.first {
            mediaButton(item)
                .frame(width: layout.singleFigureSize.width, height: layout.singleFigureSize.height)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(figures) { item in
                        mediaButton(item)
                            .frame(width: layout.multipleFigureSize.width, height: layout.multipleFigureSize.height)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func mediaButton(_ item: QuestionMediaItem) -> some View {
        Button {
            Haptics.selection()
            selected = SelectedMedia(value: item.value)
        } label: {
            QuestionMediaImage(value: item.value)
                .padding(layout.imagePadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(item.kind == .formula ? Color.white : Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.7)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.kind == .formula ? "查看公式" : "查看题目图片")
        .accessibilityHint("轻点可全屏查看并缩放")
    }

    private func mediaKind(value: String, declaredType: String) -> QuestionMediaKind {
        if declaredType.lowercased() == "formula" { return .formula }
        let lowered = value.lowercased()
        return lowered.contains("/accessories/formulas") || lowered.contains("/formulas?") ? .formula : .figure
    }
}

private enum QuestionMediaKind: Hashable { case formula, figure }

private struct QuestionMediaItem: Identifiable, Hashable {
    let value: String
    let kind: QuestionMediaKind
    var id: String { value }
}

struct QuestionContentBlock: Codable, Hashable {
    let type: String
    let text: String?
    let url: String?
    let mediaType: String?

    enum CodingKeys: String, CodingKey {
        case type, text, url
        case mediaType = "media_type"
    }
}

enum QuestionRichContentStyle: Equatable {
    case stem
    case compactStem
    case material
    case option
    case explanation
}

struct QuestionRichContent: View {
    let text: String
    let urls: [String]
    var types: [String] = []
    var blocks: [QuestionContentBlock] = []
    var style: QuestionRichContentStyle
    var tint: Color = TijingDesign.indigo

    private var effectiveBlocks: [QuestionContentBlock] {
        if !blocks.isEmpty { return blocks }
        var result: [QuestionContentBlock] = []
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(QuestionContentBlock(type: "text", text: text, url: nil, mediaType: nil))
        }
        result.append(contentsOf: urls.enumerated().map { index, url in
            QuestionContentBlock(type: "image", text: nil, url: url, mediaType: types.indices.contains(index) ? types[index] : nil)
        })
        return result
    }

    private var hasMedia: Bool {
        effectiveBlocks.contains { $0.type == "image" && $0.url?.isEmpty == false }
    }

    private var renderBlocks: [QuestionRichRenderBlock] {
        var result: [QuestionRichRenderBlock] = []
        var inlineParts: [QuestionInlinePart] = []

        func flushInline() {
            guard !inlineParts.isEmpty else { return }
            result.append(QuestionRichRenderBlock(id: result.count, inlineParts: inlineParts, urls: [], types: []))
            inlineParts = []
        }

        for block in effectiveBlocks {
            if block.type == "image", let url = block.url, !url.isEmpty {
                let declaredType = (block.mediaType ?? "").lowercased()
                let loweredURL = url.lowercased()
                let isFormula = declaredType == "formula"
                    || loweredURL.contains("/accessories/formulas")
                    || loweredURL.contains("/formulas?")
                if isFormula {
                    inlineParts.append(.formula(url))
                } else {
                    flushInline()
                    if let last = result.indices.last, result[last].inlineParts.isEmpty {
                        result[last].urls.append(url)
                        result[last].types.append(block.mediaType ?? "")
                    } else {
                        result.append(QuestionRichRenderBlock(id: result.count, inlineParts: [], urls: [url], types: [block.mediaType ?? ""]))
                    }
                }
            } else if block.type == "text", let value = block.text, !value.isEmpty,
                      style != .option || Question.shouldShowOptionText(value, hasMedia: hasMedia) {
                if let last = inlineParts.last, case .text = last {
                    inlineParts.append(.text("\n"))
                }
                inlineParts.append(.text(value))
            }
        }
        flushInline()
        return result
    }

    var body: some View {
        if style == .stem || style == .compactStem {
            HStack(alignment: .top, spacing: 12) {
                Capsule()
                    .fill(tint.opacity(0.72))
                    .frame(width: 3, height: 24)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                blockContent
            }
            .padding(.vertical, 4)
        } else {
            blockContent
        }
    }

    private var blockContent: some View {
        VStack(alignment: .leading, spacing: style == .option ? 5 : 7) {
            ForEach(renderBlocks) { block in
                if !block.inlineParts.isEmpty {
                    if block.inlineParts.contains(where: { $0.isFormula }) {
                        QuestionInlineRichText(parts: block.inlineParts, style: style)
                    } else if !block.plainText.isEmpty {
                        styledText(block.plainText)
                    }
                } else if !block.urls.isEmpty {
                    QuestionMediaStrip(
                        urls: block.urls,
                        types: block.types,
                        layout: style == .option || style == .compactStem ? .compact : .standard
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func styledText(_ value: String) -> some View {
        switch style {
        case .stem:
            Text(value).tijingQuestionStem()
        case .compactStem:
            Text(value).tijingQuestionStem(compact: true)
        case .material:
            Text(value).tijingQuestionMaterial()
        case .option:
            Text(value)
                .font(.body)
                .fontWeight(.regular)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .explanation:
            Text(value)
                .font(.body)
                .fontWeight(.regular)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private enum QuestionInlinePart: Hashable {
    case text(String)
    case formula(String)

    var isFormula: Bool {
        if case .formula = self { return true }
        return false
    }
}

private struct QuestionRichRenderBlock: Identifiable {
    let id: Int
    var inlineParts: [QuestionInlinePart]
    var urls: [String]
    var types: [String]

    var plainText: String {
        inlineParts.reduce(into: "") { result, part in
            if case .text(let value) = part { result += value }
        }
    }
}

private struct QuestionInlineRichText: View {
    let parts: [QuestionInlinePart]
    let style: QuestionRichContentStyle
    @State private var images: [String: UIImage] = [:]

    private var formulaValues: [String] {
        var seen = Set<String>()
        return parts.compactMap { part in
            guard case .formula(let value) = part, seen.insert(value).inserted else { return nil }
            return value
        }
    }

    var body: some View {
        QuestionInlineTextView(parts: parts, images: images, style: style)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: formulaValues) {
                for value in formulaValues where images[value] == nil {
                    guard !Task.isCancelled else { return }
                    if let image = await loadQuestionMediaImage(value) {
                        images[value] = image
                    }
                }
            }
    }
}

private struct QuestionInlineTextView: UIViewRepresentable {
    let parts: [QuestionInlinePart]
    let images: [String: UIImage]
    let style: QuestionRichContentStyle

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.isEditable = false
        view.isSelectable = false
        view.isScrollEnabled = false
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.widthTracksTextView = true
        view.adjustsFontForContentSizeCategory = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let value = attributedContent
        if !uiView.attributedText.isEqual(to: value) {
            uiView.attributedText = value
            uiView.invalidateIntrinsicContentSize()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let target = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let measured = uiView.sizeThatFits(target)
        return CGSize(width: width, height: ceil(measured.height))
    }

    private var attributedContent: NSAttributedString {
        let font = scaledFont
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraph,
        ]
        let result = NSMutableAttributedString(string: "")

        for part in parts {
            switch part {
            case .text(let value):
                result.append(NSAttributedString(string: value, attributes: attributes))
            case .formula(let value):
                guard let image = images[value], image.size.height > 0 else {
                    result.append(NSAttributedString(string: " □ ", attributes: attributes))
                    continue
                }
                let height = UIFontMetrics(forTextStyle: .body).scaledValue(for: formulaHeight)
                let ratio = image.size.width / image.size.height
                let width = min(max(height * ratio, height * 0.72), formulaMaxWidth)
                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = CGRect(
                    x: 0,
                    y: (font.capHeight - height) / 2 - 1,
                    width: width,
                    height: height
                )
                result.append(NSAttributedString(attachment: attachment))
            }
        }
        return result
    }

    private var scaledFont: UIFont {
        let size: CGFloat
        switch style {
        case .stem: size = 18
        case .compactStem: size = 16
        case .material: size = 17
        case .option, .explanation: size = 17
        }
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: size, weight: .regular))
    }

    private var lineSpacing: CGFloat {
        switch style {
        case .stem: 6
        case .compactStem: 4
        case .material: 7
        case .option: 3
        case .explanation: 5
        }
    }

    private var formulaHeight: CGFloat {
        switch style {
        case .compactStem: 19
        case .option: 20
        default: 22
        }
    }

    private var formulaMaxWidth: CGFloat {
        switch style {
        case .compactStem, .option: 132
        default: 190
        }
    }
}

@MainActor
private func loadQuestionMediaImage(_ value: String) async -> UIImage? {
    if let image = decodedQuestionDataImage(value) { return image }
    guard let url = APIClient.shared.assetURL(value) else { return nil }
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return nil }
        return UIImage(data: data)
    } catch {
        return nil
    }
}

private func decodedQuestionDataImage(_ value: String) -> UIImage? {
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

private struct QuestionMediaImage: View {
    let value: String

    var body: some View {
        Group {
            if let image = decodedQuestionDataImage(value) {
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
