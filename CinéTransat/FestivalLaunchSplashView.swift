//
//  FestivalLaunchSplashView.swift
//  CinéTransat
//

import SwiftUI

/// Launch splash: logo animation first, then an on-screen progress indicator while data loads.
struct FestivalLaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var isLoading: Bool
    let onAnimationComplete: () -> Void

    @State private var logoScale: CGFloat = 0.35
    @State private var logoOpacity: Double = 0.6
    @State private var didRunSequence = false

    private static let animateInDuration: TimeInterval = 0.5
    private static let holdAfterAnimate: TimeInterval = 0.15

    var body: some View {
        ZStack {
            Color.festivalProgramBackground
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image("FestivalLogo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 160)
                    .accessibilityLabel("Festival logo")

                Text(verbatim: "\(FestivalPublicConfig.currentSeasonYear)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(Color.festivalProgramTitle.opacity(0.72))
                    .accessibilityLabel("Saison \(FestivalPublicConfig.currentSeasonYear)")
            }
            .scaleEffect(logoScale, anchor: .center)
            .opacity(logoOpacity)
            .overlay(alignment: .bottom) {
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Color.festivalProgramTitle)
                        .offset(y: 52)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .accessibilityLabel("Chargement des affiches")
                }
            }
            .padding(.horizontal, 36)
            .animation(.easeOut(duration: 0.25), value: isLoading)
        }
        .onAppear(perform: runSplashSequence)
    }

    private func runSplashSequence() {
        guard !didRunSequence else { return }
        didRunSequence = true

        if reduceMotion {
            logoScale = 1
            logoOpacity = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onAnimationComplete()
            }
            return
        }

        withAnimation(.easeOut(duration: Self.animateInDuration)) {
            logoScale = 1
            logoOpacity = 1
        }

        let totalDelay = Self.animateInDuration + Self.holdAfterAnimate
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            onAnimationComplete()
        }
    }
}

#Preview("Launch splash") {
    @Previewable @State var loading = false
    FestivalLaunchSplashView(isLoading: $loading, onAnimationComplete: { loading = true })
}
