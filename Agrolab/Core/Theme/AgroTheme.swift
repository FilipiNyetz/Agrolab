//
//  AgroTheme.swift
//  Agrolab
//

import SwiftUI

/// Identidade visual do AgroLab: paleta, raios e espaçamentos.
nonisolated enum AgroTheme {
    enum Colors {
        // Verdes escuros (cabeçalhos e cartões de destaque)
        static let forest = Color(hex: 0x1B2D18)
        static let forestDeep = Color(hex: 0x111F11)
        static let forestCard = Color(hex: 0x1F3A20)

        // Verde principal (ações)
        static let primary = Color(hex: 0x4F7B2F)
        static let primaryDark = Color(hex: 0x3F6526)
        static let primarySoft = Color(hex: 0xE4EFD9)

        // Verde claro (acentos sobre fundo escuro)
        static let leaf = Color(hex: 0xA9C98A)
        static let leafMuted = Color(hex: 0x7FA05E)

        // Superfícies
        static let background = Color(hex: 0xF1F6EB)
        static let backgroundAccent = Color(hex: 0xD9E9CB)
        static let surface = Color.white
        static let fieldBackground = Color(hex: 0xF5F8F0)
        static let fieldBorder = Color(hex: 0x5F8C3C)
        static let separator = Color(hex: 0xD6DBD0)

        // Texto
        static let textPrimary = Color(hex: 0x14201A)
        static let textSecondary = Color(hex: 0x5F6B5C)
        static let textOnDark = Color.white

        // Estados
        static let danger = Color(hex: 0xC0392B)
        static let dangerSoft = Color(hex: 0xFDECEA)
        static let success = Color(hex: 0x2E7D32)
        static let successSoft = Color(hex: 0xE4F3E1)
        static let warning = Color(hex: 0xC9711A)
        static let warningSoft = Color(hex: 0xFFF2E3)
        static let warningBorder = Color(hex: 0xE8A24A)
        static let caution = Color(hex: 0xA07A00)
        static let cautionSoft = Color(hex: 0xFFF6D6)

        // Cartões neutros quentes
        static let sand = Color(hex: 0xFFF9F2)
        static let sandBorder = Color(hex: 0xDDCDB8)
    }

    enum Radius {
        static let field: CGFloat = 16
        static let button: CGFloat = 18
        static let card: CGFloat = 20
        static let header: CGFloat = 30
    }

    enum Spacing {
        static let screen: CGFloat = 24
        static let section: CGFloat = 28
    }
}

nonisolated extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
