import SwiftUI

/// First-run walkthrough shown once when there are zero GameGroups. Skippable
/// from any page; creating a group or skipping both dismiss it for good.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var isPresentingGroupForm = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppTheme.background.ignoresSafeArea()

            TabView(selection: $page) {
                OnboardingWelcomePage()
                    .tag(0)
                OnboardingFeaturesPage()
                    .tag(1)
                OnboardingGetStartedPage(
                    onCreateGroup: { isPresentingGroupForm = true },
                    onSkip: { dismiss() }
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button("Skip") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding()
        }
        .sheet(isPresented: $isPresentingGroupForm, onDismiss: { dismiss() }) {
            GroupFormView()
        }
    }
}

private struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppTheme.surface)
                    .frame(width: 120, height: 120)
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(AppTheme.accent)
            }
            VStack(spacing: 8) {
                Text("Poker Night")
                    .font(.largeTitle.weight(.bold))
                Text("Track buy-ins, cash-outs, and who owes who \u{2014} for your home game.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Spacer()
        }
    }
}

private struct OnboardingFeaturesPage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("What it does")
                .font(.title2.weight(.bold))
            VStack(alignment: .leading, spacing: 20) {
                OnboardingFeatureRow(
                    icon: "person.3.fill",
                    title: "Groups & players",
                    detail: "Keep a roster for your regular game."
                )
                OnboardingFeatureRow(
                    icon: "suit.spade.fill",
                    title: "Live sessions",
                    detail: "Track buy-ins and cash-outs as you play."
                )
                OnboardingFeatureRow(
                    icon: "arrow.left.arrow.right",
                    title: "Instant settlement",
                    detail: "The minimal set of payouts, computed for you."
                )
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct OnboardingGetStartedPage: View {
    var onCreateGroup: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.accent)
            Text("Create your first group")
                .font(.title2.weight(.bold))
            Text("Add the players in your regular game \u{2014} you can always add more later.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("Create your first group", action: onCreateGroup)
                .buttonStyle(.pill(prominent: true))
            Button("Skip for now", action: onSkip)
                .buttonStyle(.pill(prominent: false))
            Spacer()
        }
    }
}
