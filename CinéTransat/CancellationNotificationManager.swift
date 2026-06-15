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
    private let initialPromptCompletedKey = "initialNotificationPromptCompleted"

    /// Last FCM subscribe error (for Settings debug); cleared on success.
    @Published private(set) var lastTopicSubscribeError: String?

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            objectWillChange.send()
        }
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
            return false
        }
        isEnabled = true
        UserDefaults.standard.set(seasonYear, forKey: subscribedTopicYearKey)
        UIApplication.shared.registerForRemoteNotifications()
        // Topic subscribe runs from AppDelegate after APNs token is set (not here).
        if hasAPNsToken {
            await subscribeToCancellationTopic(seasonYear: seasonYear)
        } else {
            lastTopicSubscribeError = nil
            #if DEBUG
            print("Waiting for APNs token before FCM topic subscribe")
            #endif
        }
        return true
    }

    private var isSubscribingToTopic = false

    /// Call after APNs token is set — topic subscribe often fails if it runs too early.
    func resubscribeToCurrentTopicIfEnabled() async {
        guard isEnabled,
              let year = UserDefaults.standard.object(forKey: subscribedTopicYearKey) as? Int else { return }
        guard !isSubscribingToTopic else { return }
        isSubscribingToTopic = true
        defer { isSubscribingToTopic = false }
        await subscribeToCancellationTopic(seasonYear: year)
    }

    func disableNotifications() async {
        isEnabled = false
        if let year = UserDefaults.standard.object(forKey: subscribedTopicYearKey) as? Int {
            await unsubscribeFromCancellationTopic(seasonYear: year)
        }
        UserDefaults.standard.removeObject(forKey: subscribedTopicYearKey)
    }

    func syncSubscriptionIfNeeded(seasonYear: Int) async {
        guard isEnabled, authorizationStatus == .authorized || authorizationStatus == .provisional else { return }
        if hasAPNsToken {
            await subscribeToCancellationTopic(seasonYear: seasonYear)
        } else {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Called when Firestore reports newly canceled screenings (foreground / background fallback).
    func handleNewlyCanceled(_ screenings: [Screening], seasonYear: Int, language: AppLanguage) {
        guard isEnabled, !screenings.isEmpty else { return }
        Task {
            await deliverLocalCancellationAlerts(screenings, seasonYear: seasonYear, language: language)
        }
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
        print("Scheduling \(screenings.count) local cancellation alert(s)")
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
            Self.formattedScreeningDate(screening.startsAt, language: language)
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

    private static let frDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_CH")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private static let enDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private static func formattedScreeningDate(_ date: Date, language: AppLanguage) -> String {
        switch language {
        case .fr: frDateFormatter.string(from: date)
        case .en: enDateFormatter.string(from: date)
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
        if let previous = UserDefaults.standard.object(forKey: subscribedTopicYearKey) as? Int,
           previous != seasonYear {
            await unsubscribeFromCancellationTopic(seasonYear: previous)
        }
        #if canImport(FirebaseMessaging)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Messaging.messaging().subscribe(toTopic: topic) { error in
                Task { @MainActor in
                    if let error {
                        self.lastTopicSubscribeError = error.localizedDescription
                        #if DEBUG
                        print("FCM subscribe failed for \(topic): \(error.localizedDescription)")
                        #endif
                    } else {
                        self.lastTopicSubscribeError = nil
                        #if DEBUG
                        print("FCM subscribed to topic \(topic)")
                        #endif
                    }
                }
                continuation.resume()
            }
        }
        #else
        lastTopicSubscribeError = "Firebase Messaging not linked in this build."
        #endif
        UserDefaults.standard.set(seasonYear, forKey: subscribedTopicYearKey)
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
        guard fcmToken != nil else { return }
        Task { @MainActor in
            guard Messaging.messaging().apnsToken != nil else {
                #if DEBUG
                print("FCM registration token received; waiting for APNs token before topic subscribe")
                #endif
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
