import SwiftUI

struct BusinessBrand {
    let mark: String
    let background: Color
    let foreground: Color
    static func match(_ name: String) -> BusinessBrand? {
        let value = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .filter { $0.isLetter || $0.isNumber }
        let brands: [(String, String, Color, Color)] = [
            ("mcdonald", "M", Color(red: 0.75, green: 0.08, blue: 0.12), .yellow),
            ("fiveguys", "FG", Color(red: 0.8, green: 0.08, blue: 0.13), .white),
            ("burgerking", "BK", Color(red: 1, green: 0.82, blue: 0.53), Color(red: 0.7, green: 0.12, blue: 0.08)),
            ("kfc", "KFC", Color(red: 0.75, green: 0.06, blue: 0.14), .white),
            ("boudaburger", "BOU", Color(red: 0.18, green: 0.25, blue: 0.18), .white),
            ("subway", "S", Color(red: 0.03, green: 0.42, blue: 0.23), .yellow),
            ("bageterieboulevard", "BB", Color(red: 0.91, green: 0.68, blue: 0.16), .black),
            ("starbucks", "SB", Color(red: 0.03, green: 0.37, blue: 0.26), .white)
        ]
        guard let brand = brands.first(where: { value.contains($0.0) }) else { return nil }
        return .init(mark: brand.1, background: brand.2, foreground: brand.3)
    }
}

struct BusinessBadge: View {
    let name: String
    var size: CGFloat = 48
    var body: some View {
        Group {
            if let brand = BusinessBrand.match(name) {
                Text(brand.mark).font(.system(size: size * (brand.mark.count > 2 ? 0.27 : 0.39), weight: .black, design: .rounded))
                    .foregroundStyle(brand.foreground).frame(width: size, height: size)
                    .background(brand.background, in: RoundedRectangle(cornerRadius: size * 0.29))
            } else {
                Image(systemName: "storefront.fill").font(.system(size: size * 0.42))
                    .foregroundStyle(violet).frame(width: size, height: size)
                    .background(violet.opacity(0.13), in: RoundedRectangle(cornerRadius: size * 0.29))
            }
        }.accessibilityLabel(name)
    }
}
