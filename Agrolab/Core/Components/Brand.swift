//
//  Brand.swift
//  Agrolab
//

import SwiftUI

/// Logotipo (muda). Usa o asset "agrolabLogo" do catálogo; se faltar, cai para um SF Symbol.
struct BrandLogo: View {
    static let assetName = "agrolabLogo"

    var size: CGFloat = 56
    var tint: Color = AgroTheme.Colors.leaf

    var body: some View {
        Group {
            if UIImage(named: Self.assetName) != nil {
                // A arte já vem colorida e com margem interna, por isso é exibida um pouco maior.
                Image(Self.assetName)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .scaleEffect(1.35)
            } else {
                Image(systemName: "leaf.fill")
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(-12))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Logo dentro de um "tile" translúcido, como no cabeçalho de login.
struct BrandLogoTile: View {
    var size: CGFloat = 76

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(.white.opacity(0.10))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
            .overlay {
                BrandLogo(size: size * 0.55)
            }
            .frame(width: size, height: size)
    }
}

/// Wordmark "AgroLab" com o "Lab" em verde claro.
struct BrandWordmark: View {
    var size: CGFloat = 34
    var primary: Color = .white
    var accent: Color = AgroTheme.Colors.leaf

    var body: some View {
        HStack(spacing: 0) {
            Text("Agro").foregroundStyle(primary)
            Text("Lab").foregroundStyle(accent)
        }
        .font(.system(size: size, weight: .bold, design: .rounded))
        .tracking(-0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AgroLab")
    }
}

#Preview {
    ZStack {
        AgroTheme.Colors.forest.ignoresSafeArea()
        VStack(spacing: 24) {
            BrandLogoTile()
            BrandWordmark()
            BrandLogo(size: 120)
        }
    }
}
