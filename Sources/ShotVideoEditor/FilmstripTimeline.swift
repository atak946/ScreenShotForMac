import ShotCore
import SwiftUI

/// Thumbnail strip with draggable in / out handles, dimmed outside the trim and a playhead.
/// Click or drag on the strip to scrub.
struct FilmstripTimeline: View {
    let model: VideoEditorModel

    private static let height: CGFloat = 52
    private static let handleWidth: CGFloat = 12
    private static let frameStroke: CGFloat = 3
    private static let space = "filmstrip"

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                thumbnails(width: width)
                dimming(width: width)
                trimFrame(width: width)
                playhead(width: width)
                handle(isIn: true, width: width)
                handle(isIn: false, width: width)
            }
            .frame(width: width, height: Self.height)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
            .contentShape(Rectangle())
            .coordinateSpace(name: Self.space)
            .gesture(scrubGesture(width: width))
        }
        .frame(height: Self.height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Timeline", bundle: .module))
    }

    // MARK: - Layers

    private func thumbnails(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            let images = model.thumbnails
            ForEach(images.indices, id: \.self) { index in
                Image(decorative: images[index], scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width / CGFloat(max(images.count, 1)), height: Self.height)
                    .clipped()
            }
        }
        .frame(width: width, height: Self.height, alignment: .leading)
        .background(Color.black.opacity(0.6))
    }

    private func dimming(width: CGFloat) -> some View {
        let start = x(model.inPoint, width)
        let end = x(model.outPoint, width)
        return ZStack(alignment: .leading) {
            Rectangle().fill(.black.opacity(0.6)).frame(width: start)
            Rectangle().fill(.black.opacity(0.6)).frame(width: max(0, width - end)).offset(x: end)
        }
        .allowsHitTesting(false)
    }

    private func trimFrame(width: CGFloat) -> some View {
        let start = x(model.inPoint, width)
        let end = x(model.outPoint, width)
        return RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
            .strokeBorder(Color.yellow, lineWidth: Self.frameStroke)
            .frame(width: max(0, end - start), height: Self.height)
            .offset(x: start)
            .allowsHitTesting(false)
    }

    private func playhead(width: CGFloat) -> some View {
        Capsule()
            .fill(.white)
            .frame(width: 2, height: Self.height + 4)
            .shadow(color: .black.opacity(0.5), radius: 2)
            .offset(x: x(model.currentTime, width) - 1)
            .allowsHitTesting(false)
    }

    private func handle(isIn: Bool, width: CGFloat) -> some View {
        let position = x(isIn ? model.inPoint : model.outPoint, width)
        let origin = isIn ? position : position - Self.handleWidth
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.yellow)
            .overlay(Capsule().fill(.black.opacity(0.55)).frame(width: 2, height: 16))
            .frame(width: Self.handleWidth, height: Self.height)
            .offset(x: origin)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        let seconds = time(at: value.location.x, width)
                        if isIn { model.setInPoint(seconds) } else { model.setOutPoint(seconds) }
                    }
            )
            .onHover { inside in
                inside ? NSCursor.resizeLeftRight.push() : NSCursor.pop()
            }
            .accessibilityLabel(isIn ? Text("Trim start", bundle: .module) : Text("Trim end", bundle: .module))
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in model.scrub(to: time(at: value.location.x, width)) }
    }

    // MARK: - Mapping

    private func x(_ seconds: Double, _ width: CGFloat) -> CGFloat {
        guard model.duration > 0 else { return 0 }
        return CGFloat(seconds / model.duration) * width
    }

    private func time(at x: CGFloat, _ width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return Double(min(max(x / width, 0), 1)) * model.duration
    }
}
