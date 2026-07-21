//
//  AppReviewPromptSheet.swift
//  CinéTransat
//

import SwiftUI

struct AppReviewPromptSheet: View {
    let language: AppLanguage
    let onSubmit: (Int) -> Void
    let onNotNow: () -> Void

    @State private var rating = 0

    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.text("review_prompt_title", language: language))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.festivalAccent)
                .multilineTextAlignment(.center)

            Text(L10n.text("review_prompt_message", language: language))
                .font(.subheadline)
                .foregroundStyle(Color.festivalAccent.opacity(0.8))
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        rating = star
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(
                                star <= rating
                                    ? Color.festivalAccent
                                    : Color.festivalAccent.opacity(0.35)
                            )
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(starAccessibilityLabel(star))
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .contain)

            Button {
                guard rating > 0 else { return }
                onSubmit(rating)
            } label: {
                Text(L10n.text("review_prompt_submit", language: language))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.festivalAccent)
            .disabled(rating == 0)
            .opacity(rating == 0 ? 0.45 : 1)

            Button(L10n.text("review_prompt_later", language: language), action: onNotNow)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.festivalAccent.opacity(0.75))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(Color.festivalProgramBackground)
    }

    private func starAccessibilityLabel(_ star: Int) -> String {
        switch language {
        case .fr:
            return "\(star) étoile\(star > 1 ? "s" : "")"
        case .en:
            return "\(star) star\(star > 1 ? "s" : "")"
        }
    }
}
