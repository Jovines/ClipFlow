import SwiftUI

struct UpdateSettingsView: View {
    @StateObject private var updateService = UpdateService.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    private let checkIntervalOptions: [(days: Double, label: String)] = [
        (1, "Daily"),
        (7, "Weekly"),
        (30, "Monthly")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Automatic Updates".localized())
                        .font(.system(size: 14, weight: .semibold))
                }
                
                VStack(spacing: 16) {
                    Toggle(isOn: $updateService.automaticallyChecksForUpdates) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 12))
                            Text("Check for updates automatically".localized())
                                .font(.system(size: 13))
                        }
                    }
                    .toggleStyle(.checkbox)
                    
                    if updateService.automaticallyChecksForUpdates {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Check Frequency".localized())
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            
                            Picker("", selection: Binding(
                                get: {
                                    updateService.updateCheckIntervalInDays
                                },
                                set: { days in
                                    updateService.setUpdateCheckInterval(days: days)
                                }
                            )) {
                                ForEach(checkIntervalOptions, id: \.days) { option in
                                    Text(option.label).tag(option.days)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        Toggle(isOn: $updateService.automaticallyDownloadsUpdates) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 12))
                                Text("Download updates automatically".localized())
                                    .font(.system(size: 13))
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(12)
                .background(themeManager.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Current Version".localized())
                        .font(.system(size: 14, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Version".localized())
                            .font(.system(size: 13))
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    
                    if let lastCheck = updateService.lastUpdateCheckDate {
                        HStack {
                            Text("Last Checked".localized())
                                .font(.system(size: 13))
                            Spacer()
                            Text(formatDate(lastCheck))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button(action: {
                        updateService.checkForUpdates()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                            Text("Check for Updates Now".localized())
                                .font(.system(size: 13))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(12)
                .background(themeManager.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Spacer()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    UpdateSettingsView()
}
