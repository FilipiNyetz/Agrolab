//
//  AvatarBadge.swift
//  Agrolab
//

import SwiftUI

/// Círculo com as iniciais do usuário.
struct AvatarBadge: View {
    let initials: String
    var size: CGFloat = 40

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundStyle(AgroTheme.Colors.forest)
            .frame(width: size, height: size)
            .background(AgroTheme.Colors.leaf, in: Circle())
            .overlay {
                Circle().strokeBorder(AgroTheme.Colors.primaryDark.opacity(0.25), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        AvatarBadge(initials: "FR", size: 32)
        AvatarBadge(initials: "FR")
        AvatarBadge(initials: "FR", size: 72)
    }
    .padding()
}
