//
//  ScreeningCalendarService.swift
//  CinéTransat
//

import EventKit
import Foundation

enum ScreeningCalendarService {
    enum BatchAddResult: Equatable {
        case added(count: Int)
        case partial(added: Int, failed: Int)
        case denied
        case empty
    }

    private static let defaultDurationMinutes = 120
    private static let screeningIDNotePrefix = "cinetransat-screening:"

    static func location(language: AppLanguage) -> String {
        switch language {
        case .fr:
            return "Parc de la Perle du Lac, rue de Lausanne, 1202 Genève"
        case .en:
            return "La Perle du Lac park, rue de Lausanne, 1202 Geneva"
        }
    }

    static func requestAccess(using store: EKEventStore = EKEventStore()) async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess, .writeOnly:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            do {
                return try await store.requestWriteOnlyAccessToEvents()
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    static func makeEvent(
        screening: Screening,
        language: AppLanguage,
        store: EKEventStore = EKEventStore()
    ) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = "CinéTransat — \(screening.localizedTitle(language: language))"
        event.location = location(language: language)
        event.startDate = screening.startsAt
        event.endDate = endDate(for: screening)
        event.timeZone = TimeZone(identifier: "Europe/Zurich")
        event.notes = eventNotes(for: screening, language: language)
        event.calendar = store.defaultCalendarForNewEvents
        if screening.isCanceled {
            event.title = "[\(L10n.text("screening_canceled_badge", language: language))] \(event.title ?? "")"
        }
        return event
    }

    static func addUpcomingScreenings(_ screenings: [Screening], language: AppLanguage) async -> BatchAddResult {
        let eligible = screenings.filter { !$0.isCanceled && !$0.hasPassed }
        guard !eligible.isEmpty else { return .empty }

        let store = EKEventStore()
        guard await requestAccess(using: store) else { return .denied }
        guard store.defaultCalendarForNewEvents != nil else { return .partial(added: 0, failed: eligible.count) }

        var added = 0
        var failed = 0

        for screening in eligible {
            let event = makeEvent(screening: screening, language: language, store: store)
            do {
                try store.save(event, span: .thisEvent, commit: false)
                added += 1
            } catch {
                failed += 1
            }
        }

        do {
            try store.commit()
        } catch {
            return .partial(added: 0, failed: eligible.count)
        }

        if failed == 0 {
            return .added(count: added)
        }
        return .partial(added: added, failed: failed)
    }

    private static func endDate(for screening: Screening) -> Date {
        let minutes = screening.runtimeMinutes.flatMap { $0 > 0 ? $0 : nil } ?? defaultDurationMinutes
        return screening.startsAt.addingTimeInterval(TimeInterval(minutes * 60))
    }

    private static func eventNotes(for screening: Screening, language: AppLanguage) -> String {
        let freeLine = language == .fr
            ? "Projection gratuite en plein air."
            : "Free open-air screening."
        return """
        \(freeLine)
        \(screeningIDNotePrefix)\(screening.id)
        """
    }
}
