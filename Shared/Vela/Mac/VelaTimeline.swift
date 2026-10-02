// Vela additions, licensed under the Mozilla Public License 2.0.
#if targetEnvironment(macCatalyst)
import SwiftUI

struct VelaTimeline: View {
    @EnvironmentObject private var manager: MediaPlayerManager
    @EnvironmentObject private var containerState: VideoPlayerContainerState
    @StateObject private var previewSeconds = PublishedBox<Duration>(initialValue: .zero)
    @State private var hoverX: CGFloat?

    var body: some View {
        GeometryReader { geometry in
            Track(progress: progress, hover: { x in
                hoverX = x
                if let x {
                    previewSeconds.value = seconds(at: x, width: geometry.size.width)
                    containerState.timer.stop()
                } else { containerState.timer.poke() }
            }, seek: { x in
                let target = seconds(at: x, width: geometry.size.width)
                manager.proxy?.setSeconds(target)
                manager.seconds = target
                containerState.scrubbedSeconds.value = target
                containerState.timer.poke()
            })
            .overlay(alignment: .topLeading) {
                if let hoverX {
                    VStack(spacing: 6) {
                        if let provider = manager.playbackItem?.previewImageProvider {
                            VideoPlayer.PlaybackControls.PreviewImageView(previewImageProvider: provider)
                                .environmentObject(previewSeconds)
                                .frame(width: 160, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Text(previewSeconds.value, format: .minuteSecondsNarrow)
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .fixedSize()
                    .offset(x: min(max(0, hoverX - 88), max(0, geometry.size.width - 176)),
                            y: manager.playbackItem?.previewImageProvider == nil ? -44 : -140)
                    .allowsHitTesting(false)
                }
            }
        }.frame(height: 24)
        .disabled(manager.state == .loadingItem || manager.item.runtime == nil)
        .onDisappear { containerState.timer.poke() }
    }
    private var progress: CGFloat {
        guard let duration = manager.item.runtime, duration > .zero else { return 0 }
        return min(1, max(0, manager.seconds / duration))
    }
    private func seconds(at x: CGFloat, width: CGFloat) -> Duration {
        .seconds((manager.item.runtime ?? .zero).seconds * min(1, max(0, x / max(1, width))))
    }

    private struct Track: UIViewRepresentable {
        let progress: CGFloat
        let hover: (CGFloat?) -> Void
        let seek: (CGFloat) -> Void
        func makeUIView(context: Context) -> TrackView { TrackView() }
        func updateUIView(_ view: TrackView, context: Context) {
            view.progress = progress; view.hover = hover; view.seek = seek
            view.accessibilityValue = "\(Int(progress * 100)) %"
            view.setNeedsLayout()
        }
    }
    private final class TrackView: UIView {
        var progress: CGFloat = 0
        var hover: ((CGFloat?) -> Void)?
        var seek: ((CGFloat) -> Void)?
        let track = CALayer()
        let fill = CALayer()
        override init(frame: CGRect) {
            super.init(frame: frame)
            accessibilityIdentifier = "VelaTimeline"
            accessibilityLabel = "Wiedergabeposition"
            isAccessibilityElement = true
            accessibilityTraits = .adjustable
            track.backgroundColor = UIColor.white.withAlphaComponent(0.25).cgColor
            fill.backgroundColor = UIColor.white.cgColor
            track.cornerRadius = 3; fill.cornerRadius = 3
            layer.addSublayer(track); layer.addSublayer(fill)
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(_:))))
            addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
            addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(over(_:))))
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin(); CATransaction.setDisableActions(true)
            track.frame = CGRect(x: 0, y: bounds.midY - 3, width: bounds.width, height: 6)
            fill.frame = CGRect(x: 0, y: bounds.midY - 3, width: bounds.width * progress, height: 6)
            CATransaction.commit()
        }
        @objc func tap(_ gesture: UITapGestureRecognizer) { seek?(gesture.location(in: self).x) }
        @objc func pan(_ gesture: UIPanGestureRecognizer) {
            let x = gesture.location(in: self).x
            switch gesture.state {
            case .ended: seek?(x); hover?(nil)
            case .cancelled, .failed: hover?(nil)
            default: hover?(x)
            }
        }
        override func accessibilityIncrement() { seek?(bounds.width * min(1, progress + 0.01)) }
        override func accessibilityDecrement() { seek?(bounds.width * max(0, progress - 0.01)) }
        @objc func over(_ gesture: UIHoverGestureRecognizer) {
            hover?(gesture.state == .ended || gesture.state == .cancelled ? nil : gesture.location(in: self).x)
        }
    }
}
#endif
