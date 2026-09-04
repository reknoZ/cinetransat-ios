//
//  FestivalLaunchSplashView.swift
//  CinéTransat
//

import SwiftUI

/// Launch splash: logo animation first, then an on-screen progress indicator while data loads.
struct FestivalLaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue

    @Binding var isLoading: Bool
    let seasonEnded: Bool
    let seasonYear: Int
    let onAnimationComplete: () -> Void

    @State private var logoScale: CGFloat = 0.35
    @State private var logoOpacity: Double = 0.6
    @State private var messageOpacity: Double = 0
    @State private var didRunSequence = false
    @State private var didRequestContinue = false

    private static let animateInDuration: TimeInterval = 0.5
    private static let holdAfterAnimate: TimeInterval = 0.15

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

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

                if seasonEnded {
                    VStack(spacing: 10) {
                        Text(
                            String(
                                format: L10n.text("splash_season_ended_title", language: appLanguage),
                                seasonYear
                            )
                        )
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.festivalAccent)

                        Text(L10n.text("splash_season_ended_message", language: appLanguage))
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.festivalProgramTitle)
                    }
                    .opacity(messageOpacity)
                    .accessibilityElement(children: .combine)
                } else {
                    Text(verbatim: "\(seasonYear)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(Color.festivalAccent)
                        .accessibilityLabel("Saison \(seasonYear)")
                }
            }
            .scaleEffect(logoScale, anchor: .center)
            .opacity(logoOpacity)
            .overlay(alignment: .bottom) {
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Color.festivalAccent)
                        .offset(y: seasonEnded ? 72 : 52)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .accessibilityLabel("Chargement des affiches")
                }
            }
            .padding(.horizontal, 36)
            .animation(.easeOut(duration: 0.25), value: isLoading)

            if seasonEnded, !isLoading, !didRequestContinue {
                VStack {
                    Spacer()
                    Button(action: continueFromSeasonEnded) {
                        Text(L10n.text("splash_season_ended_continue", language: appLanguage))
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.festivalAccent)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 40)
                    .opacity(messageOpacity)
                    .accessibilityIdentifier("splash_season_ended_continue")
                }
            }
        }
        .onAppear(perform: runSplashSequence)
    }

    private func continueFromSeasonEnded() {
        guard !didRequestContinue else { return }
        didRequestContinue = true
        onAnimationComplete()
    }

    private func runSplashSequence() {
        guard !didRunSequence else { return }
        didRunSequence = true

        if reduceMotion {
            logoScale = 1
            logoOpacity = 1
            messageOpacity = 1
            if !seasonEnded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onAnimationComplete()
                }
            }
            return
        }

        withAnimation(.easeOut(duration: Self.animateInDuration)) {
            logoScale = 1
            logoOpacity = 1
        }

        if seasonEnded {
            withAnimation(.easeOut(duration: 0.35).delay(Self.animateInDuration * 0.4)) {
                messageOpacity = 1
            }
            return
        }

        let totalDelay = Self.animateInDuration + Self.holdAfterAnimate
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            onAnimationComplete()
        }
    }
}

#Preview("Launch splash") {
    @Previewable @State var loading = false
    FestivalLaunchSplashView(
        isLoading: $loading,
        seasonEnded: false,
        seasonYear: 2026,
        onAnimationComplete: { loading = true }
    )
}

#Preview("Season ended splash") {
    @Previewable @State var loading = false
    FestivalLaunchSplashView(
        isLoading: $loading,
        seasonEnded: true,
        seasonYear: 2026,
        onAnimationComplete: { loading = true }
    )
}
