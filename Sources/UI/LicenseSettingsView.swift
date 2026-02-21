import SwiftUI

public struct LicenseSettingsView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @State private var inputKey: String = ""
    @State private var isVerifying: Bool = false
    @State private var errorMessage: String?
    
    public init() {}
    
    public var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("EchoFlow Pro")
                        .font(.headline)
                    
                    Text("Enter your license key to unlock all features. You can purchase a license key online.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if licenseManager.isLicenseValid {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("License Active")
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 8)
                        
                        Button("Deactivate License", role: .destructive) {
                            deactivate()
                        }
                    } else {
                        HStack {
                            SecureField("License Key (e.g., LSQ-....)", text: $inputKey)
                                .textFieldStyle(.roundedBorder)
                                .disabled(isVerifying)
                            
                            Button(action: {
                                verifyKey()
                            }) {
                                if isVerifying {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(width: 50)
                                } else {
                                    Text("Activate")
                                        .frame(width: 50)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(inputKey.isEmpty || isVerifying)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Link("Purchase License", destination: URL(string: "https://echoflow.ai/buy")!)
                            .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .frame(width: 450, height: 250)
    }
    
    private func verifyKey() {
        guard !inputKey.isEmpty else { return }
        errorMessage = nil
        isVerifying = true
        
        Task {
            do {
                let isValid = try await licenseManager.validate(key: inputKey)
                DispatchQueue.main.async {
                    self.isVerifying = false
                    if isValid {
                        self.inputKey = "" // Clear on success
                    } else {
                        self.errorMessage = "Invalid or expired license key."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isVerifying = false
                    self.errorMessage = "Verification failed. Check your internet connection."
                }
            }
        }
    }
    
    private func deactivate() {
        do {
            try licenseManager.deactivate()
        } catch {
            errorMessage = "Failed to deactivate license securely."
        }
    }
}
