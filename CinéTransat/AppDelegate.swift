//
//  AppDelegate.swift
//  CinéTransat
//

import UIKit
import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// SwiftUI app delegate — `@objc` + `nonisolated` so Firebase can see a real `UIApplicationDelegate` under Swift 6 MainActor defaults.
@objc(AppDelegate)
final class AppDelegate: NSObject, UIApplicationDelegate {
    @objc nonisolated func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    @objc nonisolated func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #if DEBUG
        print("APNs device token set — subscribing to FCM topic if alerts enabled")
        #endif
        Task { @MainActor in
            await CancellationNotificationManager.shared.resubscribeToCurrentTopicIfEnabled()
        }
        #endif
    }

    /// Required when `FirebaseAppDelegateProxyEnabled` is NO — forwards FCM/APNs payloads so pushes work in background / when the app is closed.
    @objc nonisolated func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().appDidReceiveMessage(userInfo)
        #endif
        completionHandler(.newData)
    }

    @objc nonisolated func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        Task { @MainActor in
            print("APNs registration failed: \(error.localizedDescription)")
        }
        #endif
    }
}
