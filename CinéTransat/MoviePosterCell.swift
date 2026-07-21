//
//  MoviePosterCell.swift
//  CinéTransat
//

import SwiftUI
import UIKit

struct MoviePosterCell: View {
    @EnvironmentObject private var program: FestivalProgramStore
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.fr.rawValue

    let screening: Screening
    var compact: Bool = false
    /// When set, poster is drawn at this width (height = width × 3/2). Otherwise uses flexible aspect-ratio tile.
    var posterWidth: CGFloat? = nil
    var isOnWatchList: Bool = false
    /// When false, bookmark is hidden unless already on the list (shown disabled — no add/remove).
    var watchListEnabled: Bool = true
    /// Top-left day pill on the poster (e.g. off for Watch List rows where the date appears beside the title).
    var showDateBadge: Bool = true
    /// Watch list tab: dim poster and show countdown while a removal is pending.
    var isPendingRemoval: Bool = false
    var removalSecondsLeft: Int = 5
    /// When set, the bookmark is a tappable button (e.g. detail page and Programme grid).
    var onWatchListToggle: (() -> Void)? = nil

    private var showsWatchListControl: Bool {
        watchListEnabled || isOnWatchList
    }

    private var watchListInteractive: Bool {
        onWatchListToggle != nil
    }

    /// Day + short month (no time), e.g. "10 juil." / "Jul 10"
    private var posterBadgeDay: String {
        FestivalDateFormatters.posterBadgeDay(screening.startsAt, language: appLanguage)
    }

    private var cornerRadius: CGFloat { compact ? 12 : 16 }

    private var canceledOverlaySpacing: CGFloat {
        if let w = posterWidth {
            return min(8, max(3, w * 0.09))
        }
        return compact ? 6 : 8
    }

    private var canceledRainEmojiSize: CGFloat {
        if let w = posterWidth {
            return min(78, max(22, w * 0.42))
        }
        return compact ? 56 : 92
    }

    private var canceledAnnuleFont: Font {
        if let w = posterWidth {
            if w < 58 {
                return .caption2.weight(.heavy)
            }
            if w < 82 {
                return .caption.weight(.heavy)
            }
            if w < 130 {
                return .subheadline.weight(.heavy)
            }
        }
        return compact ? .headline : .title3
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fr
    }

    private var showPassedBadge: Bool {
        screening.hasPassed && !screening.isCanceled
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(posterBackdropFill)
                .overlay {
                    if !screening.usesTBDPlaceholderPoster {
                        Image(systemName: "film.fill")
                            .font(.system(size: compact ? 36 : 52, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.12))
                    }
                }

            posterImageLayer
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .overlay {
            if screening.isCanceled {
                ZStack {
                    Color.black.opacity(0.50)
                    VStack(spacing: canceledOverlaySpacing) {
                        Text("🌧️")
                            .font(.system(size: canceledRainEmojiSize))
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                        Text(L10n.text("screening_canceled_badge", language: appLanguage))
                            .font(canceledAnnuleFont)
                            .foregroundStyle(.white)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .overlay {
            if isPendingRemoval {
                ZStack {
                    Color.black.opacity(0.58)
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("\(removalSecondsLeft)")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .overlay(alignment: .topLeading) {
            if showDateBadge {
                Text(posterBadgeDay)
                    .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
                    .foregroundStyle(screening.hasPassed ? Color.white.opacity(0.85) : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, compact ? 6 : 7)
                    .padding(.vertical, compact ? 4 : 5)
                    .background {
                        RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous)
                            .fill(Color.black.opacity(screening.hasPassed ? 0.55 : 0.78))
                            .overlay {
                                RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                            }
                    }
                    .padding(5)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showPassedBadge {
                Text(L10n.text("screening_passed", language: appLanguage))
                    .font(compact ? .caption2.weight(.heavy) : .caption.weight(.heavy))
                    .foregroundStyle(Color(white: 0.22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, compact ? 6 : 7)
                    .padding(.vertical, compact ? 4 : 5)
                    .background {
                        RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                            .overlay {
                                RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                            }
                    }
                    .padding(5)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showsWatchListControl {
                Group {
                    if let tap = onWatchListToggle {
                        Button(action: tap) {
                            watchListBookmarkLabel
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            isOnWatchList
                                ? L10n.text("watchlist_remove", language: appLanguage)
                                : L10n.text("watchlist_add", language: appLanguage)
                        )
                    } else {
                        watchListBookmarkLabel
                            .accessibilityHidden(true)
                    }
                }
                .opacity(watchListInteractive ? 1 : 0.45)
                .allowsHitTesting(watchListInteractive)
            }
        }
        .modifier(PosterSizingModifier(posterWidth: posterWidth))
        .shadow(color: .black.opacity(0.35), radius: compact ? 7 : 10, x: 0, y: compact ? 4 : 5)
        .shadow(color: Color.festivalAccent.opacity(0.15), radius: compact ? 4 : 6, x: 0, y: 0)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.festivalAccent, lineWidth: 1)
        }
        .opacity(screening.hasPassed ? 0.72 : 1)
        .saturation(screening.hasPassed ? 0.45 : 1)
    }

    private var watchListBookmarkLabel: some View {
        Image(systemName: isOnWatchList ? "bookmark.fill" : "bookmark")
            .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(isOnWatchList ? Color.festivalAccent : Color.white.opacity(0.92))
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 5 : 6)
            .background(
                (isOnWatchList ? Color.festivalProgramBackground : Color.black).opacity(0.72),
                in: Circle()
            )
            .padding(6)
    }

    private var posterBackdropFill: AnyShapeStyle {
        if screening.usesTBDPlaceholderPoster {
            return AnyShapeStyle(Color(red: 0.55, green: 0.57, blue: 0.60))
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.14, blue: 0.22),
                    Color(red: 0.05, green: 0.06, blue: 0.12),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var posterImageLayer: some View {
        ScreeningPosterImage(
            screening: screening,
            posterBaseURLTemplate: program.publicConfig.posterBaseURL
        )
    }
}

private struct PosterSizingModifier: ViewModifier {
    let posterWidth: CGFloat?

    func body(content: Content) -> some View {
        if let w = posterWidth {
            let h = w * 3 / 2
            content
                .frame(width: w, height: h, alignment: .center)
        } else {
            content
                .aspectRatio(2 / 3, contentMode: .fit)
        }
    }
}

#Preview {
    MoviePosterCell(
        screening: FestivalProgramBootstrap.weeks[1].orderedScreenings[2],
        compact: false
    )
    .environmentObject(FestivalProgramStore.preview)
    .padding()
    .frame(width: 160)
}
