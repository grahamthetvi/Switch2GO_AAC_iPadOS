import SwiftUI

/// Validation mode shown after calibration to test accuracy
struct CalibrationValidationView: View {
    @EnvironmentObject var gazeManager: GazeTrackingManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var testPoints: [CGPoint] = []
    @State private var currentTestIndex = 0
    @State private var validationResults: [ValidationResult] = []
    @State private var showingResults = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if !showingResults {
                    // Validation test grid
                    validationTestView(geometry: geometry)
                } else {
                    // Results view
                    validationResultsView
                }
            }
        }
        .statusBarHidden()
        .onAppear {
            generateTestPoints(in: UIScreen.main.bounds.size)
        }
    }
    
    private func validationTestView(geometry: GeometryProxy) -> some View {
        VStack {
            Spacer()
            
            // Test target
            if let point = testPoints[safe: currentTestIndex] {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)
                    .position(point)
            }
            
            Spacer()
            
            // Instructions
            VStack(spacing: 16) {
                Text("Validation Test")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Look at point \(currentTestIndex + 1) of \(testPoints.count)")
                    .foregroundColor(.gray)
                
                Button("Next Point") {
                    recordValidationPoint()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Skip Validation") {
                    dismiss()
                }
                .foregroundColor(.gray)
            }
            .padding(.bottom, 60)
        }
    }
    
    private var validationResultsView: some View {
        VStack(spacing: 32) {
            Image(systemName: averageAccuracy > 0.8 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(averageAccuracy > 0.8 ? .green : .orange)
            
            Text("Validation Complete")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                Text("Average Accuracy")
                    .foregroundColor(.gray)
                
                Text("\(Int(averageAccuracy * 100))%")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(averageAccuracy > 0.8 ? .green : .orange)
            }
            
            Text(accuracyMessage)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                if averageAccuracy < 0.8 {
                    Button("Recalibrate") {
                        // Restart calibration
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    private func generateTestPoints(in size: CGSize) {
        // Generate 5-point test grid (corners + center)
        let margin: CGFloat = 100
        testPoints = [
            CGPoint(x: margin, y: margin),
            CGPoint(x: size.width - margin, y: margin),
            CGPoint(x: size.width / 2, y: size.height / 2),
            CGPoint(x: margin, y: size.height - margin),
            CGPoint(x: size.width - margin, y: size.height - margin)
        ]
    }
    
    private func recordValidationPoint() {
        guard let testPoint = testPoints[safe: currentTestIndex] else { return }
        
        // Record where the user is actually looking vs where they should be
        let gazePoint = gazeManager.gazePosition
        let distance = sqrt(pow(gazePoint.x - testPoint.x, 2) + pow(gazePoint.y - testPoint.y, 2))
        
        let result = ValidationResult(
            targetPoint: testPoint,
            gazePoint: gazePoint,
            errorDistance: distance
        )
        validationResults.append(result)
        
        if currentTestIndex < testPoints.count - 1 {
            currentTestIndex += 1
        } else {
            showingResults = true
        }
    }
    
    private var averageAccuracy: Double {
        guard !validationResults.isEmpty else { return 0 }
        
        let maxError: CGFloat = 100
        let avgError = validationResults.reduce(0) { $0 + $1.errorDistance } / CGFloat(validationResults.count)
        return max(0, 1.0 - Double(min(avgError / maxError, 1.0)))
    }
    
    private var accuracyMessage: String {
        switch averageAccuracy {
        case 0.9...1.0: return "Excellent! Eye tracking is highly accurate."
        case 0.8..<0.9: return "Good accuracy. Eye tracking should work well."
        default: return "Consider recalibrating for better accuracy."
        }
    }
}

struct ValidationResult {
    let targetPoint: CGPoint
    let gazePoint: CGPoint
    let errorDistance: CGFloat
}

#Preview {
    CalibrationValidationView()
        .environmentObject(GazeTrackingManager())
}
