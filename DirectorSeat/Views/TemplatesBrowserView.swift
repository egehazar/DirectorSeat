import SwiftUI

struct TemplatesBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: FilmTemplate?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Templates")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)

                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(Theme.Spacing.xs)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)

            Text("Proven story shapes. Fill in your details.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.top, Theme.Spacing.sm)

            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(FilmTemplate.library) { template in
                        TemplateCard(template: template)
                            .onTapGesture {
                                selectedTemplate = template
                            }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedTemplate) { template in
            TemplateDetailView(template: template)
        }
    }
}

// MARK: - Template Card

private struct TemplateCard: View {
    let template: FilmTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(template.mood.uppercased())
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.accent)
                .tracking(1.5)

            Text(template.title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(template.description)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(2)

            Text("\(template.scenes.count) scenes \u{00B7} \(template.totalShots) shots \u{00B7} ~\(template.estimatedDurationMinutes)min final \u{00B7} ~\(template.estimatedShootMinutes)min to shoot \u{00B7} \(template.castLabel)")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        TemplatesBrowserView()
    }
}
