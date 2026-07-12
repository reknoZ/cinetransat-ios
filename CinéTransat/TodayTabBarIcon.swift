//
//  TodayTabBarIcon.swift
//  CinéTransat
//
//  Tab bar calendar glyph with today's day of month (Geneva), template-tinted like SF Symbols.
//

import UIKit

enum TodayTabBarIcon {
    static var dayOfMonth: Int {
        FestivalCalendar.current.component(.day, from: Date())
    }

    static func image(day: Int = dayOfMonth) -> UIImage {
        let clampedDay = min(31, max(1, day))
        let pointSize: CGFloat = 25
        let size = CGSize(width: pointSize, height: pointSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1.2, dy: 1.2)
            let headerHeight = rect.height * 0.28
            let headerRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: headerHeight)
            let bodyRect = CGRect(
                x: rect.minX,
                y: rect.minY + headerHeight,
                width: rect.width,
                height: rect.height - headerHeight
            )

            UIColor.black.setFill()
            UIColor.black.setStroke()

            let path = UIBezierPath(roundedRect: rect, cornerRadius: 3.2)
            path.lineWidth = 1.4
            path.stroke()

            UIBezierPath(roundedRect: headerRect, cornerRadius: 2.4).fill()

            let ringsY = rect.minY - 1.6
            let ringRadius: CGFloat = 1.15
            let ringCenters = [rect.minX + rect.width * 0.28, rect.minX + rect.width * 0.72]
            for x in ringCenters {
                UIBezierPath(
                    ovalIn: CGRect(
                        x: x - ringRadius,
                        y: ringsY - ringRadius,
                        width: ringRadius * 2,
                        height: ringRadius * 2
                    )
                ).fill()
            }

            let dayText = "\(clampedDay)" as NSString
            let fontSize: CGFloat = clampedDay >= 10 ? 11.5 : 13
            let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph,
            ]
            let textSize = dayText.size(withAttributes: attributes)
            let textRect = CGRect(
                x: bodyRect.minX,
                y: bodyRect.midY - textSize.height / 2 - 0.5,
                width: bodyRect.width,
                height: textSize.height
            )
            dayText.draw(in: textRect, withAttributes: attributes)
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}
