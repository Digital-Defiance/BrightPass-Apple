import SwiftUI

// MARK: - Error Banner (dismissible, with retry for retryable errors)

/// A dismissible banner for network/server errors.
/// Shows a retry button when the error is retryable.
@available(macOS 14.0, iOS 17.0, *)
public struct ErrorBannerView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    public init(error: AppError, onRetry: (() -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)

            Text(error.userMessage)
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(3)

            Spacer()

            if error.isRetryable, let onRetry {
                Button("Retry") { onRetry() }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.small)
                    .accessibilityLabel("Retry action")
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(12)
        .background(bannerColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var bannerColor: Color {
        switch error {
        case .networkUnavailable: return .orange
        case .serverError: return .red
        case .sessionExpired: return .purple
        case .validationError: return .yellow.opacity(0.8)
        default: return .red
        }
    }
}

// MARK: - Inline Validation Error

/// Displays inline validation error messages below form fields.
@available(macOS 14.0, iOS 17.0, *)
public struct InlineValidationError: View {
    let messages: [String]

    public init(_ messages: [String]) {
        self.messages = messages
    }

    public init(_ message: String) {
        self.messages = [message]
    }

    public var body: some View {
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(messages, id: \.self) { message in
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                        Text(message)
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Validation errors: \(messages.joined(separator: ", "))")
        }
    }
}

// MARK: - Session Expired Sheet

/// Modal sheet presented when the session expires, prompting re-authentication.
@available(macOS 14.0, iOS 17.0, *)
public struct SessionExpiredSheet: View {
    @Bindable var authViewModel: AuthViewModel
    let onDismiss: () -> Void

    public init(authViewModel: AuthViewModel, onDismiss: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text("Session Expired")
                    .font(.title2.bold())

                Text("Your session has expired. Please log in again to continue.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                LoginView(viewModel: authViewModel)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }
}

// MARK: - Full-Screen Loading Overlay

/// Full-screen overlay with a progress indicator, used during vault unlock.
@available(macOS 14.0, iOS 17.0, *)
public struct LoadingOverlay: View {
    let message: String

    public init(message: String = "Loading…") {
        self.message = message
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

// MARK: - Error Presentation View Modifier

/// A view modifier that adds error banner presentation and session expiry handling.
@available(macOS 14.0, iOS 17.0, *)
struct ErrorPresentationModifier: ViewModifier {
    @Binding var error: AppError?
    let onRetry: (() -> Void)?
    @Binding var showSessionExpired: Bool
    let authViewModel: AuthViewModel?

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let error {
                ErrorBannerView(
                    error: error,
                    onRetry: onRetry,
                    onDismiss: { withAnimation { self.error = nil } }
                )
                .padding(.top, 8)
                .zIndex(100)
            }
        }
        .sheet(isPresented: $showSessionExpired) {
            if let auth = authViewModel {
                SessionExpiredSheet(authViewModel: auth) {
                    showSessionExpired = false
                }
            }
        }
        .onChange(of: error) { _, newError in
            if case .sessionExpired = newError {
                showSessionExpired = true
                self.error = nil
            }
        }
    }
}

@available(macOS 14.0, iOS 17.0, *)
public extension View {
    /// Adds error banner presentation with optional retry and session expiry sheet.
    func errorPresentation(
        error: Binding<AppError?>,
        onRetry: (() -> Void)? = nil,
        showSessionExpired: Binding<Bool> = .constant(false),
        authViewModel: AuthViewModel? = nil
    ) -> some View {
        modifier(ErrorPresentationModifier(
            error: error,
            onRetry: onRetry,
            showSessionExpired: showSessionExpired,
            authViewModel: authViewModel
        ))
    }
}
