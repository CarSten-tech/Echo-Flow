import SwiftUI

public struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentStep = 0
    
    public init() {}
    
    public var body: some View {
        VStack {
            TabView(selection: $currentStep) {
                WelcomeView(nextAction: { currentStep = 1 })
                    .tag(0)
                
                PermissionsStepView(nextAction: { currentStep = 2 })
                    .tag(1)
                
                FinishView(finishAction: {
                    hasCompletedOnboarding = true
                })
                .tag(2)
            }
            // TabViewStyle .page is iOS only, omitting it for macOS. We rely on the button to advance state.
            .animation(.easeInOut, value: currentStep)
            
            HStack {
                Spacer()
                if currentStep < 2 {
                    Button("Next") {
                        currentStep += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

struct WelcomeView: View {
    var nextAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            
            Text("Welcome to EchoFlow")
                .font(.largeTitle)
                .bold()
            
            Text("The fastest way to convert your speech to text and inject it anywhere on your Mac.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.top, 50)
    }
}

struct PermissionsStepView: View {
    var nextAction: () -> Void
    
    var body: some View {
        VStack {
            PermissionsView()
        }
    }
}

struct FinishView: View {
    var finishAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.green)
            
            Text("You're all set!")
                .font(.largeTitle)
                .bold()
            
            Text("EchoFlow is now running in your menu bar. Press your hotkey to start capturing.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button("Start Using EchoFlow", action: finishAction)
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 30)
        }
        .padding(.top, 50)
    }
}
