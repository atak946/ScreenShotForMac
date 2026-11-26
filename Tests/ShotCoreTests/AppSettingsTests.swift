import Foundation
@testable import ShotCore
import Testing

/// Fresh, isolated UserDefaults suite removed when the test finishes.
private final class TemporaryDefaults {
    let name = "ShotCoreTests.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: name))
    }

    deinit {
        defaults.removePersistentDomain(forName: name)
    }
}

@MainActor
@Suite("AppSettings")
struct AppSettingsTests {
    @Test("Empty defaults produce documented defaults")
    func defaultsWhenEmpty() throws {
        let store = try TemporaryDefaults()
        let settings = AppSettings(defaults: store.defaults)
        #expect(settings.afterCapture == .showQuickAccess)
        #expect(settings.alsoCopyToClipboard)
        #expect(settings.imageFormat == .png)
        #expect(settings.imageQuality == 0.9)
        #expect(!settings.downscaleRetina)
        #expect(settings.filenameTemplate == "Screenshot {date} at {time}")
        #expect(settings.saveFolderBookmark == nil)
        #expect(settings.captureWindowShadow)
        #expect(settings.showMagnifier)
        #expect(settings.colorFormat == .hex)
        #expect(settings.ocrLanguages == ["en-US", "tr-TR"])
        #expect(settings.quickAccessAutoCloseSeconds == 8)
        #expect(settings.captureDelaySeconds == 3)
        #expect(settings.recordShowCursor)
        #expect(settings.recordFramesPerSecond == 30)
        #expect(settings.gifFramesPerSecond == 15)
        #expect(settings.historyEnabled)
        #expect(settings.historyRetentionDays == 30)
        #expect(settings.editorCloseAfterSave)
        #expect(settings.appLanguage == .system)
        #expect(!settings.hasCompletedOnboarding)
    }

    @Test("Capture and output settings survive a reload from the same suite")
    func capturePersistenceRoundTrip() throws {
        let store = try TemporaryDefaults()
        let settings = AppSettings(defaults: store.defaults)
        settings.afterCapture = .openEditor
        settings.alsoCopyToClipboard = false
        settings.imageFormat = .heic
        settings.imageQuality = 0.5
        settings.downscaleRetina = true
        settings.filenameTemplate = "Shot {counter}"
        settings.saveFolderBookmark = Data([1, 2, 3])
        settings.captureWindowShadow = false
        settings.showMagnifier = false
        settings.colorFormat = .swiftUI
        settings.ocrLanguages = ["de-DE"]
        settings.quickAccessAutoCloseSeconds = 0
        settings.captureDelaySeconds = 10

        let reloaded = AppSettings(defaults: store.defaults)
        #expect(reloaded.afterCapture == .openEditor)
        #expect(!reloaded.alsoCopyToClipboard)
        #expect(reloaded.imageFormat == .heic)
        #expect(reloaded.imageQuality == 0.5)
        #expect(reloaded.downscaleRetina)
        #expect(reloaded.filenameTemplate == "Shot {counter}")
        #expect(reloaded.saveFolderBookmark == Data([1, 2, 3]))
        #expect(!reloaded.captureWindowShadow)
        #expect(!reloaded.showMagnifier)
        #expect(reloaded.colorFormat == .swiftUI)
        #expect(reloaded.ocrLanguages == ["de-DE"])
        #expect(reloaded.quickAccessAutoCloseSeconds == 0)
        #expect(reloaded.captureDelaySeconds == 10)
    }

    @Test("Recording, history and editor settings survive a reload from the same suite")
    func recordingPersistenceRoundTrip() throws {
        let store = try TemporaryDefaults()
        let settings = AppSettings(defaults: store.defaults)
        settings.recordSystemAudio = true
        settings.recordMicrophone = true
        settings.recordShowCursor = false
        settings.recordHighlightClicks = true
        settings.recordFramesPerSecond = 60
        settings.gifFramesPerSecond = 10
        settings.openTrimEditorAfterRecording = true
        settings.historyEnabled = false
        settings.historyRetentionDays = 0
        settings.editorCloseAfterSave = false
        settings.hasCompletedOnboarding = true

        let reloaded = AppSettings(defaults: store.defaults)
        #expect(reloaded.recordSystemAudio)
        #expect(reloaded.recordMicrophone)
        #expect(!reloaded.recordShowCursor)
        #expect(reloaded.recordHighlightClicks)
        #expect(reloaded.recordFramesPerSecond == 60)
        #expect(reloaded.gifFramesPerSecond == 10)
        #expect(reloaded.openTrimEditorAfterRecording)
        #expect(!reloaded.historyEnabled)
        #expect(reloaded.historyRetentionDays == 0)
        #expect(!reloaded.editorCloseAfterSave)
        #expect(reloaded.hasCompletedOnboarding)
    }

    @Test("Unknown raw values fall back to defaults")
    func invalidRawValuesFallBack() throws {
        let store = try TemporaryDefaults()
        store.defaults.set("bogus", forKey: "afterCapture")
        store.defaults.set("tiff", forKey: "imageFormat")
        store.defaults.set("cmyk", forKey: "colorFormat")
        store.defaults.set("xx", forKey: "appLanguage")
        let settings = AppSettings(defaults: store.defaults)
        #expect(settings.afterCapture == .showQuickAccess)
        #expect(settings.imageFormat == .png)
        #expect(settings.colorFormat == .hex)
        #expect(settings.appLanguage == .system)
    }

    @Test("MP4 options use the recording FPS and audio preferences")
    func recordingOptionsMP4() throws {
        let store = try TemporaryDefaults()
        let settings = AppSettings(defaults: store.defaults)
        settings.recordSystemAudio = true
        settings.recordMicrophone = true
        settings.recordShowCursor = false
        settings.recordHighlightClicks = true
        settings.recordFramesPerSecond = 60
        settings.gifFramesPerSecond = 12

        let options = settings.recordingOptions(format: .mp4)
        #expect(options == RecordingOptions(
            format: .mp4, captureSystemAudio: true, captureMicrophone: true,
            showCursor: false, highlightClicks: true, framesPerSecond: 60
        ))
    }

    @Test("GIF options never capture audio and use the GIF FPS")
    func recordingOptionsGIF() throws {
        let store = try TemporaryDefaults()
        let settings = AppSettings(defaults: store.defaults)
        settings.recordSystemAudio = true
        settings.recordMicrophone = true
        settings.recordFramesPerSecond = 60
        settings.gifFramesPerSecond = 12

        let options = settings.recordingOptions(format: .gif)
        #expect(options.format == .gif)
        #expect(!options.captureSystemAudio)
        #expect(!options.captureMicrophone)
        #expect(options.framesPerSecond == 12)
    }

    @Test("App language is persisted and applied as the AppleLanguages override")
    func appLanguageWrites() throws {
        let store = try TemporaryDefaults()
        let settings = AppSettings(defaults: store.defaults)
        defer { settings.appLanguage = .system }

        settings.appLanguage = .turkish
        #expect(store.defaults.string(forKey: "appLanguage") == "tr")
        #expect(UserDefaults.standard.stringArray(forKey: "AppleLanguages") == ["tr"])

        settings.appLanguage = .english
        #expect(UserDefaults.standard.stringArray(forKey: "AppleLanguages") == ["en"])
        #expect(AppSettings(defaults: store.defaults).appLanguage == .english)

        settings.appLanguage = .system
        #expect(store.defaults.string(forKey: "appLanguage") == "system")
        let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String]
        #expect(UserDefaults.standard.stringArray(forKey: "AppleLanguages") == global)
    }

    @Test("Image formats map to file extensions")
    func imageFormatExtensions() {
        #expect(ImageFormat.png.fileExtension == "png")
        #expect(ImageFormat.jpeg.fileExtension == "jpg")
        #expect(ImageFormat.heic.fileExtension == "heic")
    }

    @Test("Native language names are not translated")
    func nativeNames() {
        #expect(AppLanguage.english.nativeName == "English")
        #expect(AppLanguage.turkish.nativeName == "Türkçe")
        #expect(!AppLanguage.system.nativeName.isEmpty)
    }
}
