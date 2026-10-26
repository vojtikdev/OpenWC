import SwiftUI
import Supabase

@main
struct OpenWCApp: App {
    @StateObject private var store = AppStore()
    @AppStorage("appearance") private var appearance = "dark"
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .tint(.purple)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
        }
    }
}

enum Backend {
    static let client: SupabaseClient? = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: raw), url.scheme == "https", !raw.contains("YOUR_PROJECT"),
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as? String,
              !key.isEmpty, !key.contains("YOUR_PUBLISHABLE") else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()
}
