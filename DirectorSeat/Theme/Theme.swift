import SwiftUI

enum Theme {
    enum Colors {
        static let background = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
        static let surface = Color(red: 22 / 255, green: 22 / 255, blue: 22 / 255)
        static let textPrimary = Color.white
        static let textSecondary = Color.gray.opacity(0.7)
        static let accent = Color(red: 245 / 255, green: 241 / 255, blue: 234 / 255)
        static let buttonPrimary = Color.white
    }

    enum Typography {
        static let title = Font.system(size: 22, weight: .semibold)
        static let heroTitle = Font.system(size: 28, weight: .semibold)
        static let headline = Font.system(size: 22, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let caption = Font.system(size: 13, weight: .medium)

        // Performer View — sized for reading at arm's length / across a room.
        // Deliberately larger than the dense Shooting Mode direction card.
        static let performerLine = Font.system(size: 36, weight: .semibold)
        static let performerDirection = Font.system(size: 24, weight: .regular)
        static let performerCue = Font.system(size: 20, weight: .medium)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
}
