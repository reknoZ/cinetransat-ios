//
//  FestivalLaunchSplashView.swift
//  CinéTransat
//

import SwiftUI

/// Full-screen splash: logo scales from a dot at the center to full layout size, then calls `onFinished`.
struct FestivalLaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onFinished: () -> Void

    @State private var logoScale: CGFloat = 0.02

    /// Extra time the full-size logo stays on screen before handing off to the programme.
    private static let postZoomHoldNanoseconds: UInt64 = 2_500_000_000

    var body: some View {
        ZStack {
            Color.festivalProgramBackground
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image("FestivalLogo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: 320, maxHeight: 200)
                    .accessibilityLabel("Festival logo")

                Text(verbatim: "\(FestivalProgramData.demoYear)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.primary.opacity(0.72))
                    .accessibilityLabel("Saison \(FestivalProgramData.demoYear)")
            }
            .padding(.horizontal, 36)
            .scaleEffect(logoScale, anchor: .center)
        }
        .task {
            if reduceMotion {
                logoScale = 1
                try? await Task.sleep(nanoseconds: 400_000_000)
            } else {
                withAnimation(.spring(response: 0.92, dampingFraction: 0.78, blendDuration: 0)) {
                    logoScale = 1
                }
                try? await Task.sleep(nanoseconds: 1_050_000_000)
            }
            try? await Task.sleep(nanoseconds: Self.postZoomHoldNanoseconds)
            onFinished()
        }
    }
}

#Preview("Launch splash") {
    FestivalLaunchSplashView(onFinished: {})
}

#Preview("Launch splash (start frame)") {
    ZStack {
        Color.festivalProgramBackground
            .ignoresSafeArea()
        VStack(spacing: 14) {
            Image("FestivalLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 200)
            Text(verbatim: "\(FestivalProgramData.demoYear)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .tracking(6)
                .foregroundStyle(.primary.opacity(0.72))
        }
        .padding(.horizontal, 36)
        .scaleEffect(0.02, anchor: .center)
    }
}
