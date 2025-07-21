import SwiftUI

// @main - Commented out to avoid conflicts with main app  
struct BasicAgentCodeRemoteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Clauder Remote")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("iOS app is ready!")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Get Started") {
                // TODO: Add functionality
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}