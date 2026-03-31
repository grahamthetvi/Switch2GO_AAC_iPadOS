import SwiftUI

/// Timing and Sensitivity settings
struct TimingSensitivityView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsHomeAction) private var settingsHomeAction
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hover Time Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hover Time")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("How long to dwell on a button before selection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Slider(value: $settings.dwellTime, in: 0.5...5.0, step: 0.1)
                            .accentColor(.blue)
                        
                        Text("\(settings.dwellTime, specifier: "%.1f") seconds")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Repeat Hover Activation Section
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $settings.enableRepeatDwell) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Repeat Hover Activation")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("If enabled, keeping the cursor on a button will activate it again")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.blue)
                    
                    if settings.enableRepeatDwell {
                        Divider()
                            .padding(.vertical, 4)
                        
                        Text("Repeat Delay")
                            .font(.headline)
                        
                        Text("How long to wait before activating again")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Slider(value: $settings.repeatDwellDelay, in: 0.5...5.0, step: 0.1)
                                .accentColor(.blue)
                            
                            Text("\(settings.repeatDwellDelay, specifier: "%.1f") seconds")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Cursor Sensitivity Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cursor Sensitivity")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Pointer movement speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        sensitivityButton(level: 0, label: "Low")
                        sensitivityButton(level: 1, label: "Medium")
                        sensitivityButton(level: 2, label: "High")
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(settings.appBorderColor)
        .environment(\.colorScheme, settings.preferredColorScheme)
        .navigationTitle("Timing & Sensitivity")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    settingsHomeAction?() ?? dismiss()
                }) {
                    Label("Home", systemImage: "house.fill")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .toolbarBackground(settings.appBorderColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    private func sensitivityButton(level: Int, label: String) -> some View {
        Button(action: {
            settings.sensitivity = level
        }) {
            Text(label)
                .font(.headline)
                .foregroundColor(settings.sensitivity == level ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(settings.sensitivity == level ? Color.blue : Color(UIColor.tertiarySystemBackground))
                .cornerRadius(10)
        }
    }
}

#Preview {
    NavigationStack {
        TimingSensitivityView()
    }
}
