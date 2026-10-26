import SwiftUI

struct AuthView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var register: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var showPassword = false
    @State private var acceptedTerms = false
    @State private var legal: LegalDocument?
    @FocusState private var focused: Field?
    private enum Field { case email, password, confirmation }

    private var emailValid: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
    private var canSubmit: Bool {
        emailValid && !password.isEmpty && (!register || (password.count >= 8 && password == confirmation && acceptedTerms)) && !store.loading
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 30)).foregroundStyle(violet)
                        .padding(18).background(violet.opacity(0.14), in: RoundedRectangle(cornerRadius: 22))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(register ? "A more open city\nstarts with you." : "Your city.\nA little more open.")
                            .font(.system(size: 34, weight: .bold, design: .rounded)).tracking(-1)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(register ? "Create an account to share places and help someone nearby." : "Log in to find shared codes and pick up where you left off.")
                            .foregroundStyle(.secondary)
                    }
                    Picker("Account action", selection: $register) {
                        Text("Log in").tag(false)
                        Text("Register").tag(true)
                    }.pickerStyle(.segmented).disabled(store.loading)
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email address").font(.subheadline.weight(.semibold))
                            TextField("you@example.com", text: $email)
                                .textContentType(.emailAddress).keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .focused($focused, equals: .email).submitLabel(.next)
                                .onSubmit { focused = .password }
                                .padding(16).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password").font(.subheadline.weight(.semibold))
                            HStack {
                                Group {
                                    if showPassword { TextField("Your password", text: $password) }
                                    else { SecureField("Your password", text: $password) }
                                }
                                .textContentType(register ? .newPassword : .password)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .focused($focused, equals: .password)
                                .submitLabel(register ? .next : .go)
                                .onSubmit { if register { focused = .confirmation } else { submit() } }
                                Button { showPassword.toggle() } label: { Image(systemName: showPassword ? "eye.slash" : "eye").foregroundStyle(.secondary) }
                                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                            }.padding(16).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                            if register { Text("Use at least 8 characters.").font(.caption).foregroundStyle(.secondary) }
                        }
                        if register {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm password").font(.subheadline.weight(.semibold))
                                SecureField("Repeat your password", text: $confirmation)
                                    .textContentType(.newPassword).focused($focused, equals: .confirmation)
                                    .submitLabel(.done).onSubmit { focused = nil }
                                    .padding(16).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                                if !confirmation.isEmpty && confirmation != password {
                                    Text("Your passwords don’t match yet.").font(.caption).foregroundStyle(.red)
                                }
                            }
                            Toggle(isOn: $acceptedTerms) {
                                Text("I agree to the Terms of Service.").font(.subheadline)
                            }.tint(violet)
                            Text("Read the Privacy Policy to understand how OpenWC uses your data. Location and photos are optional.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.disabled(store.loading)
                    if let message = store.message {
                        Label(message, systemImage: "info.circle")
                            .font(.callout).foregroundStyle(.secondary)
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                            .accessibilityIdentifier("authMessage")
                    }
                    Button(action: submit) {
                        HStack {
                            Spacer()
                            if store.loading { ProgressView().tint(.white) }
                            Text(register ? "Create account" : "Log in").fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                            Spacer()
                        }.padding(18).foregroundStyle(.white)
                            .background(canSubmit ? violet : Color.gray.opacity(0.35), in: Capsule())
                    }.disabled(!canSubmit)
                    HStack {
                        Button("Terms of Service") { legal = .terms }
                        Spacer()
                        Button("Privacy Policy") { legal = .privacy }
                    }.font(.caption)
                    Text("© 2026 Vojtěch Klepáček").font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }.padding(24)
            }
            .background(Color(uiColor: .systemBackground))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(register ? "Create account" : "Welcome back")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(store.loading) } }
            .sheet(item: $legal) { LegalDocumentView(document: $0) }
            .onChange(of: register) { _, _ in store.message = nil; confirmation = ""; acceptedTerms = false }
            .onChange(of: store.user?.id) { _, value in if value != nil { dismiss() } }
            .onAppear { store.message = nil }
            .interactiveDismissDisabled(store.loading)
        }
    }
    private func submit() {
        guard canSubmit else { return }
        focused = nil
        Task {
            await store.authenticate(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, register: register, acceptedTerms: acceptedTerms)
        }
    }
}
