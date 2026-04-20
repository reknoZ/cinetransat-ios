//
//  MoviePosterCell.swift
//  CinéTransat
//

import SwiftUI
import UIKit

struct MoviePosterCell: View {
    let screening: Screening
    var compact: Bool = false
    /// When set, poster is drawn at this width (height = width × 3/2). Otherwise uses flexible aspect-ratio tile.
    var posterWidth: CGFloat? = nil
    var isOnWatchList: Bool = false
    /// Top-left day pill on the poster (e.g. off for Watch List rows where the date appears beside the title).
    var showDateBadge: Bool = true
    /// When set, the bookmark is a tappable button (e.g. detail page and Programme grid).
    var onWatchListToggle: (() -> Void)? = nil

    /// Day + short month (no time), e.g. "10 juil."
    private static let dayOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_CH")
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f
    }()

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

    private var resolvedAssetName: String? {
        guard let name = screening.posterAssetName, UIImage(named: name, in: .main, compatibleWith: nil) != nil else {
            return nil
        }
        return name
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.14, blue: 0.22),
                            Color(red: 0.05, green: 0.06, blue: 0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: "film.fill")
                        .font(.system(size: compact ? 36 : 52, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.12))
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
                        Text("Annulé")
                            .font(canceledAnnuleFont)
                            .foregroundStyle(.white)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .overlay(alignment: .topLeading) {
            if showDateBadge {
                Text(Self.dayOnlyFormatter.string(from: screening.startsAt))
                    .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, compact ? 6 : 7)
                    .padding(.vertical, compact ? 4 : 5)
                    .background {
                        RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous)
                            .fill(Color.black.opacity(0.78))
                            .overlay {
                                RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                            }
                    }
                    .padding(5)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Group {
                if let tap = onWatchListToggle {
                    Button(action: tap) {
                        watchListBookmarkLabel
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isOnWatchList ? "Remove from watch list" : "Add to watch list")
                } else {
                    watchListBookmarkLabel
                }
            }
        }
        .modifier(PosterSizingModifier(posterWidth: posterWidth))
    }

    private var watchListBookmarkLabel: some View {
        Image(systemName: isOnWatchList ? "bookmark.fill" : "bookmark")
            .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(isOnWatchList ? Color.white : Color.white.opacity(0.92))
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 5 : 6)
            .background(Color.black.opacity(0.45), in: Circle())
            .padding(6)
    }

    @ViewBuilder
    private var posterImageLayer: some View {
        if let name = resolvedAssetName {
            GeometryReader { geo in
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    // Slight zoom trims embedded white borders/inconsistent source margins.
                    .scaleEffect(1.04)
                    .clipped()
            }
        } else {
            Color.clear
        }
    }
}

private struct PosterSizingModifier: ViewModifier {
    let posterWidth: CGFloat?

    func body(content: Content) -> some View {
        if let w = posterWidth {
            let h = w * 3 / 2
            content
                .frame(width: w, height: h, alignment: .center)
                .clipped()
        } else {
            content
                .aspectRatio(2 / 3, contentMode: .fit)
        }
    }
}

#Preview {
    MoviePosterCell(
        screening: FestivalProgramData.weeks[1].orderedScreenings[2],
        compact: false
    )
    .padding()
    .frame(width: 160)
}
