import SwiftUI
import UIKit

/// Settings → App Icon. Replaces the former inline `Picker`, which listed the
/// icons by name only and gave no hint what any of them looked like, with a
/// pushed page of artwork tiles.
///
/// The tiles render `AppIcon.previewAssetName` imagesets rather than the
/// `.appiconset` artwork directly: `UIImage(named:)` does not resolve the
/// primary app icon by its asset name, so reading previews out of the icon
/// sets would leave the default tile blank.
///
/// Selection applies the moment a tile is tapped, and the system — not
/// `Preferences` — persists it in `UIApplication.alternateIconName`. When iOS
/// declines the switch (Guided Access, a management profile), `selection`
/// snaps back to the icon actually installed and a banner explains why.
struct AppIconPickerView: View {
    @Binding var selection: AppIcon
    @State private var failed = false

    private let tileSize: CGFloat = 88

    var body: some View {
        ScrollView {
            if UIApplication.shared.supportsAlternateIcons {
                grid
            } else {
                unsupported
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.screenBackground)
        .safeAreaInset(edge: .top) {
            if failed {
                ErrorBanner(
                    message: String(localized: "appIconPicker.error.failed"),
                    accessibilityLabel: Text("appIconPicker.error.failed"),
                    identifier: "appIconPicker.errorBanner",
                )
            }
        }
        .navigationTitle("appIconPicker.nav.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: tileSize + 24), spacing: 20)],
            spacing: 20,
        ) {
            ForEach(AppIcon.allCases) { icon in
                AppIconTile(icon: icon, size: tileSize, isSelected: icon == selection) {
                    select(icon)
                }
            }
        }
        .padding(20)
    }

    private var unsupported: some View {
        ContentUnavailableView(
            "appIconPicker.unsupported.title",
            systemImage: "app.dashed",
            description: Text("appIconPicker.unsupported.description"),
        )
        .accessibilityIdentifier("appIconPicker.emptyState")
        .padding(.top, 40)
    }

    private func select(_ icon: AppIcon) {
        let previous = selection
        selection = icon
        failed = false
        // The live UIKit value, not `previous`, decides whether a switch is
        // needed — `selection` can lag reality after a failed attempt.
        guard icon.alternateIconName != UIApplication.shared.alternateIconName else { return }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(icon.alternateIconName)
            } catch {
                selection = previous
                failed = true
            }
        }
    }
}

/// One artwork tile. The rounded-rect mask approximates the Home Screen
/// squircle (iOS masks app icons at ~22% of their width).
private struct AppIconTile: View {
    let icon: AppIcon
    let size: CGFloat
    let isSelected: Bool
    let action: () -> Void

    private var cornerRadius: CGFloat {
        size * 0.22
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                artwork
                Text(LocalizedStringKey(icon.titleKey))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? AppTheme.accent : Color.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(icon.titleKey)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("a11y.appIconPicker.option.hint"))
        .accessibilityIdentifier("appIconPicker.option.\(icon.rawValue)")
    }

    private var artwork: some View {
        Image(icon.previewAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? AppTheme.accent : AppTheme.border,
                        lineWidth: isSelected ? 3 : 1,
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    // Shape companion to the accent-colored ring, so the
                    // selected tile reads without relying on color alone.
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, AppTheme.accent)
                        .padding(4)
                }
            }
            .accessibilityHidden(true)
    }
}
