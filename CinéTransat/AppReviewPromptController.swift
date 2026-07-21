//
//  AppReviewPromptController.swift
//  CinéTransat
//
//  Soft “Like this app?” prompt after enough cumulative foreground use.
//  Custom star sheet → StoreKit review (4–5★) or feedback mail (1–3★).
//

import Combine
import Foundation
import StoreKit
import SwiftUI
import UIKit

@MainActor
final class AppReviewPromptController: ObservableObject {
    static let shared = AppReviewPromptController()

    /// Soft prompt after this much cumulative foreground time (~middle of 5–10 min).
    private static let minActiveSeconds: TimeInterval = 8 * 60
    /// After “Not now”, ask again about once a week for the rest of the season.
    private static let minDaysBetweenPrompts: Double = 7
    /// Ratings at or above this open the system App Store review sheet.
    private static let storeReviewMinStars = 4

    private static let activeSecondsKey = "appReview.totalActiveSeconds"
    private static let lastPromptKey = "appReview.lastPromptAt"
    /// Set when the user submits stars or rates from Settings.
    private static let completedReviewKey = "appReview.completedReviewAction"

    @Published var isPresentingPrompt = false
    /// When set after a low-star submit, root presents the feedback mail composer.
    @Published var pendingFeedbackSeasonYear: Int?

    private var tickTimer: Timer?
    private var sessionStartedAt: Date?
    private var promptedThisSession = false
    private var handledCurrentPresentation = false

    private init() {}

    func handleScenePhase(_ phase: ScenePhase) {
        guard !AppStoreScreenshotConfiguration.isActive else { return }
        switch phase {
        case .active:
            beginTracking()
            evaluatePromptIfNeeded()
        case .inactive, .background:
            endTracking()
        @unknown default:
            endTracking()
        }
    }

    func dismissWithoutAction() {
        guard isPresentingPrompt else { return }
        handledCurrentPresentation = true
        recordPromptShown()
        isPresentingPrompt = false
    }

    /// Called when the sheet is dismissed (swipe / submit / Not now).
    func handleSheetDismissed() {
        if !handledCurrentPresentation {
            recordPromptShown()
        }
        handledCurrentPresentation = false
    }

    func submitRating(_ stars: Int, seasonYear: Int) {
        guard stars > 0 else { return }
        handledCurrentPresentation = true
        markReviewActionCompleted()
        isPresentingPrompt = false

        if stars >= Self.storeReviewMinStars {
            requestSystemReview()
        } else {
            pendingFeedbackSeasonYear = seasonYear
        }
    }

    func clearPendingFeedback() {
        pendingFeedbackSeasonYear = nil
    }

    /// Call from Settings (or elsewhere) when the user opens the rating / review flow themselves.
    func markReviewActionCompleted() {
        UserDefaults.standard.set(true, forKey: Self.completedReviewKey)
        recordPromptShown()
    }

    private func requestSystemReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else {
            return
        }
        AppStore.requestReview(in: scene)
    }

    private func beginTracking() {
        sessionStartedAt = Date()
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.accumulateActiveTime()
                self?.evaluatePromptIfNeeded()
            }
        }
        if let timer = tickTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func endTracking() {
        accumulateActiveTime()
        tickTimer?.invalidate()
        tickTimer = nil
        sessionStartedAt = nil
    }

    private func accumulateActiveTime() {
        guard let started = sessionStartedAt else { return }
        let now = Date()
        let delta = now.timeIntervalSince(started)
        sessionStartedAt = now
        guard delta > 0, delta < 120 else { return }
        let total = UserDefaults.standard.double(forKey: Self.activeSecondsKey) + delta
        UserDefaults.standard.set(total, forKey: Self.activeSecondsKey)
    }

    private func evaluatePromptIfNeeded() {
        guard !promptedThisSession, !isPresentingPrompt else { return }
        guard !UserDefaults.standard.bool(forKey: Self.completedReviewKey) else { return }

        let total = UserDefaults.standard.double(forKey: Self.activeSecondsKey)
        guard total >= Self.minActiveSeconds else { return }

        if let last = UserDefaults.standard.object(forKey: Self.lastPromptKey) as? Date {
            let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            guard Double(days) >= Self.minDaysBetweenPrompts else { return }
        }

        promptedThisSession = true
        handledCurrentPresentation = false
        isPresentingPrompt = true
    }

    private func recordPromptShown() {
        UserDefaults.standard.set(Date(), forKey: Self.lastPromptKey)
    }
}
