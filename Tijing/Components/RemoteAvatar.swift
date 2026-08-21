import SwiftUI

struct RemoteAvatar: View {
    let urlString: String?
    let name: String
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            placeholder

            if let url = APIClient.shared.assetURL(urlString) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.22))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    case .failure:
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: max(14, size * 0.34), weight: .medium))
                            .foregroundStyle(.tertiary)
                    default:
                        ProgressView()
                            .controlSize(size >= 54 ? .regular : .small)
                            .tint(.secondary)
                    }
                }
                .id(url.absoluteString)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.secondary.opacity(0.22), lineWidth: 0.6))
        .accessibilityLabel("\(name)的头像")
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Color.secondary.opacity(0.10))
            Text(String(name.prefix(1)))
                .font(.system(size: max(14, size * 0.36), weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}
