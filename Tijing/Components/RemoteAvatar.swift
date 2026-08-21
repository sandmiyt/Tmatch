import SwiftUI

struct RemoteAvatar: View {
    let urlString: String?
    let name: String
    var size: CGFloat = 46

    var body: some View {
        Group {
            if let url = APIClient.shared.assetURL(urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))
        .accessibilityLabel("\(name)的头像")
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(.quaternary)
            Text(String(name.prefix(1)))
                .font(.system(size: max(14, size * 0.36), weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}
