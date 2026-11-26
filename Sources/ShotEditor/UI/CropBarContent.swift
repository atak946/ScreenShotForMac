import ShotCore
import SwiftUI

/// Crop mode bar: aspect presets, Cancel and Apply.
struct CropBarContent: View {
    let viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            HStack(spacing: 2) {
                ForEach(CropAspect.allCases) { aspect in
                    Button(aspect.title) { viewModel.setCropAspect(aspect) }
                        .buttonStyle(ChromeButtonStyle(isSelected: viewModel.cropAspect == aspect, height: 26))
                        .help(String(localized: "Aspect Ratio", bundle: .module) + " \(aspect.title)")
                }
            }
            ToolbarDivider()
            Button(String(localized: "Cancel", bundle: .module)) { viewModel.cancelCrop() }
                .buttonStyle(ChromeButtonStyle(height: 26))
                .help(String(localized: "Cancel", bundle: .module) + "  esc")
            Button(String(localized: "Apply", bundle: .module)) { viewModel.applyCrop() }
                .buttonStyle(PrimaryPillButtonStyle())
                .help(String(localized: "Apply", bundle: .module) + "  ↩")
        }
    }
}
