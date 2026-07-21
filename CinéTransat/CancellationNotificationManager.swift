//
//  CancellationNotificationManager.swift
//  CinéTransat
//

import Combine
import Foundation
import UIKit
import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// Cancellation alerts via FCM push (app closed). Local notifications are only a fallback when Firestore updates while the app is already running.
@MainActor
final class CancellationNotificationManager: NSObject, ObservableObject {
    static let shared = CancellationNotificationManager()

    private let enabledKey = "cancellationNotificationsEnabled"
    private let subscribedTopicYearKey = "cancellationNotificationsTopicYear"
    private let targetTopicYearKey = "cancellationNotificationsTargetYear"
    private let initialPromptCompletedKey = "initialNotificationPromptCompleted"

    /// Last FCM subscribe error (for Settings debug); cleared on success.
    @Published private(set) var lastTopicSubscribeError: String?

    /// True after a successful FCM topic subscribe for the current season.
    @Published private(set) var isSubscribedToTopic = false

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            objectWillChange.send()
        }
    }

    private var subscribedSeasonYear: Int? {
        UserDefaults.standard.object(forKey: subscribedTopicYearKey) as? Int
    }

    private var targetSeasonYear: Int? {
        subscribedSeasonYear
            ?? UserDefaults.standard.object(forKey: targetTopicYearKey) as? Int
    }

    private override init() {
        super.init()
    }

    /// Call once at startup from `Cine_TransatApp.init` (MainActor) — not from `AppDelegate` (Swift 6 isolation).
    static func installDelegates() {
        UNUserNotificationCenter.current().delegate = shared
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = shared
        #endif
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Human-readable push pipeline status for Settings.
    func deliveryStatusSummary(language: AppLanguage, seasonYear: Int) -> String? {
        guard isEnabled else { return nil }
        switch authorizationStatus {
        case .denied:
            return L10n.text("settings_notifications_denied", language: language)
        default:
            break
        }
        if let err = lastTopicSubscribeError {
            return err
        }
        if isSubscribedToTopic {
            return nil
        }
        if !hasAPNsToken {
            return L10n.text("settings_notifications_status_waiting_apns", language: language)
        }
        return L10n.text("settings_notifications_status_connecting", language: language)
    }

    /// On first install, shows the standard iOS notification permission dialog once.
    func promptForNotificationsOnFirstLaunchIfNeeded(seasonYear: Int) async {
        guard !UserDefaults.standard.bool(forKey: initialPromptCompletedKey) else { return }
        UserDefaults.standard.set(true, forKey: initialPromptCompletedKey)

        await refreshAuthorizationStatus()
        guard authorizationStatus == .notDetermined else { return }

        _ = await enableNotifications(seasonYear: seasonYear)
    }

    /// Requests permission, registers for APNs, and subscribes to the season FCM topic.
    @discardableResult
    func enableNotifications(seasonYear: Int) async -> Bool {
        let granted = await requestAuthorization()
        guard granted else {
            isEnabled = false
            isSubscribedToTopic = false
            return false
        }
        isEnabled = true
        lastTopicSubscribeError = nil
        UserDefaults.standard.set(seasonYear, forKey: targetTopicYearKey)
        UIApplication.shared.registerForRemoteNotifications()
        await waitForAPNsAndSubscribe(seasonYear: seasonYear)
        return true
    }

    private var isSubscribingToTopic = false

    /// Call after APNs token is set — topic subscribe often fails if it runs too early.
    func resubscribeToCurrentTopicIfEnabled() async {
        guard isEnabled, let year = targetSeasonYear else { return }
        await waitForAPNsAndSubscribe(seasonYear: year)
    }

    func disableNotifications() async {
        isEnabled = false
        isSubscribedToTopic = false
        if let year = subscribedSeasonYear {
            await unsubscribeFromCancellationTopic(seasonYear: year)
        }
        UserDefaults.standard.removeObject(forKey: subscribedTopicYearKey)
        UserDefaults.standard.removeObject(forKey: targetTopicYearKey)
    }

    func syncSubscriptionIfNeeded(seasonYear: Int) async {
        guard isEnabled, authorizationStatus == .authorized || authorizationStatus == .provisional else { return }
        if hasAPNsToken {
            await subscribeToCancellationTopic(seasonYear: seasonYear)
        } else {
            UIApplication.shared.registerForRemoteNotifications()
            await waitForAPNsAndSubscribe(seasonYear: seasonYear)
        }
    }

    /// Called when Firestore reports newly canceled screenings (foreground / background fallback).
    func handleNewlyCanceled(_ screenings: [Screening], seasonYear: Int, language: AppLanguage) {
        let tonight = screenings.filter(\.isFestivalDayToday)
        guard isEnabled, !tonight.isEmpty else { return }
        Task {
            await deliverLocalCancellationAlerts(tonight, seasonYear: seasonYear, language: language)
        }
    }

    func handleAPNsRegistrationFailure(_ error: Error) {
        isSubscribedToTopic = false
        let language = AppLanguage(
            rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.fr.rawValue
        ) ?? .fr
        lastTopicSubscribeError = String(
            format: L10n.text("settings_notifications_apns_failed", language: language),
            error.localizedDescription
        )
        #if DEBUG
        print("APNs registration failed: \(error.localizedDescription)")
        #endif
    }

    // MARK: - Private

    private func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    /// Retries until APNs token is available or times out (~30 s).
    private func waitForAPNsAndSubscribe(seasonYear: Int) async {
        guard !isSubscribingToTopic else { return }
        isSubscribingToTopic = true
        defer { isSubscribingToTopic = false }

        for attempt in 1...15 {
            if hasAPNsToken {
                await subscribeToCancellationTopic(seasonYear: seasonYear)
                return
            }
            UIApplication.shared.registerForRemoteNotifications()
            #if DEBUG
            print("Waiting for APNs token (attempt \(attempt)/15) before FCM topic subscribe")
            #endif
            try? await Task.sleep(for: .seconds(2))
        }

        isSubscribedToTopic = false
        let language = AppLanguage(
            rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.fr.rawValue
        ) ?? .fr
        lastTopicSubscribeError = L10n.text("settings_notifications_apns_timeout", language: language)
        #if DEBUG
        print("APNs token not received — topic subscribe timed out")
        #endif
    }

    private func deliverLocalCancellationAlerts(
        _ screenings: [Screening],
        seasonYear: Int,
        language: AppLanguage
    ) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        default:
            #if DEBUG
            print(
                "Local notification skipped: iOS authorization status = \(settings.authorizationStatus.rawValue) (enable in Settings → CinéTransat → Notifications)"
            )
            #endif
            return
        }

        #if DEBUG
        print("Scheduling \(screenings.count) local cancellation alert(s) — app is running (Firestore fallback, not lock-screen push)")
        #endif

        for screening in screenings {
            await scheduleLocalNotification(for: screening, seasonYear: seasonYear, language: language)
        }
    }

    private func scheduleLocalNotification(
        for screening: Screening,
        seasonYear: Int,
        language: AppLanguage
    ) async {
        let content = UNMutableNotificationContent()
        content.title = L10n.text("notification_cancel_title", language: language)
        content.body = String(
            format: L10n.text("notification_cancel_body", language: language),
            screening.localizedTitle(language: language),
            FestivalDateFormatters.screeningDay(screening.startsAt, language: language)
        )
        content.sound = .default
        content.userInfo = [
            "screeningId": screening.id,
            "seasonYear": seasonYear,
        ]

        let request = UNNotificationRequest(
            identifier: "cancel-\(screening.id)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            #if DEBUG
            print("Local notification queued for screening \(screening.id)")
            #endif
        } catch {
            #if DEBUG
            print("Local notification failed for \(screening.id): \(error.localizedDescription)")
            #endif
        }
    }

    private var hasAPNsToken: Bool {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken != nil
        #else
        false
        #endif
    }

    private func subscribeToCancellationTopic(seasonYear: Int) async {
        guard hasAPNsToken else { return }

        let topic = Self.cancellationTopic(seasonYear: seasonYear)
        if let previous = subscribedSeasonYear, previous != seasonYear {
            await unsubscribeFromCancellationTopic(seasonYear: previous)
        }

        #if canImport(FirebaseMessaging)
        let subscribeError: String? = await withCheckedContinuation { continuation in
            Messaging.messaging().subscribe(toTopic: topic) { error in
                continuation.resume(returning: error?.localizedDescription)
            }
        }
        if let subscribeError {
            isSubscribedToTopic = false
            lastTopicSubscribeError = subscribeError
            #if DEBUG
            print("FCM subscribe failed for \(topic): \(subscribeError)")
            #endif
            return
        }

        isSubscribedToTopic = true
        lastTopicSubscribeError = nil
        UserDefaults.standard.set(seasonYear, forKey: subscribedTopicYearKey)
        #if DEBUG
        print("FCM subscribed to topic \(topic)")
        if let fcmToken = Messaging.messaging().fcmToken {
            print("FCM token (for Firebase test message): \(fcmToken)")
        }
        #endif
        #else
        isSubscribedToTopic = false
        lastTopicSubscribeError = "Firebase Messaging not linked in this build."
        #endif
    }

    private func unsubscribeFromCancellationTopic(seasonYear: Int) async {
        #if canImport(FirebaseMessaging)
        let topic = Self.cancellationTopic(seasonYear: seasonYear)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Messaging.messaging().unsubscribe(fromTopic: topic) { _ in
                continuation.resume()
            }
        }
        #endif
        isSubscribedToTopic = false
    }

    static func cancellationTopic(seasonYear: Int) -> String {
        "season_\(seasonYear)_cancellations"
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension CancellationNotificationManager: UNUserNotificationCenterDelegate {
    @objc nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        #if DEBUG
        print("Presenting notification banner in foreground: \(notification.request.identifier)")
        #endif
        return [.banner, .list, .sound, .badge]
    }
}

// MARK: - MessagingDelegate

#if canImport(FirebaseMessaging)
extension CancellationNotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        #if DEBUG
        if let fcmToken {
            print("FCM registration token: \(fcmToken)")
        }
        #endif
        Task { @MainActor in
            guard isEnabled else { return }
            if Messaging.messaging().apnsToken == nil {
                #if DEBUG
                print("FCM token received; waiting for APNs token before topic subscribe")
                #endif
                UIApplication.shared.registerForRemoteNotifications()
                return
            }
            #if DEBUG
            print("FCM token ready — subscribing to topic if alerts enabled")
            #endif
            await resubscribeToCurrentTopicIfEnabled()
        }
    }
}
#endif
