import SwiftUI

/// About window displaying app information, version, credits, and links.
struct AboutView: View {
    @Environment(\.openURL) private var openURL

    /// URL to the Oura website.
    private let ouraURL = URL(string: "https://ouraring.com/")!

    /// App version from the bundle.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Build number from the bundle.
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            Image(systemName: "heart.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // App Name and Version
            VStack(spacing: 4) {
                Text("Commander")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Description
            Text("A menu bar companion for your Oura Ring that displays your daily readiness and sleep scores.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Divider()
                .padding(.horizontal, 40)

            // Credits
            VStack(spacing: 8) {
                Text("Data provided by")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    openURL(ouraURL)
                } label: {
                    HStack(spacing: 4) {
                        Text("Oura")
                            .fontWeight(.medium)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
                .buttonStyle(.link)
            }

            Spacer()

            // Copyright
            Text("© 2024 Commander")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(width: 320, height: 380)
    }
}

#Preview {
    AboutView()
}
