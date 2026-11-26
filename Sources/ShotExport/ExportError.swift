import Foundation

/// Errors thrown by the export pipeline.
public enum ExportError: LocalizedError, Sendable {
    case encodingFailed(format: String)
    case writeFailed(path: String, reason: String)
    case folderUnavailable(path: String)
    case bookmarkResolutionFailed(reason: String)
    case scalingFailed

    public var errorDescription: String? {
        switch self {
        case let .encodingFailed(format):
            return String(localized: "Could not encode the image as \(format.uppercased()).", bundle: .module)
        case let .writeFailed(path, reason):
            return String(localized: "Could not write the file to \(path): \(reason)", bundle: .module)
        case let .folderUnavailable(path):
            return String(localized: "The save folder is not accessible: \(path). Choose another folder in Settings.", bundle: .module)
        case let .bookmarkResolutionFailed(reason):
            return String(
                localized: "The saved folder could not be resolved: \(reason). Choose the folder again in Settings.",
                bundle: .module
            )
        case .scalingFailed:
            return String(localized: "Could not resize the image.", bundle: .module)
        }
    }
}
