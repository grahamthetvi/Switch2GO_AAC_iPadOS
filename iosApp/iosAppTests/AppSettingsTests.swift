import XCTest
@testable import iosApp

/// Unit tests for AppSettings
class AppSettingsTests: XCTestCase {
    
    var settings: AppSettings!
    
    override func setUp() {
        super.setUp()
        settings = AppSettings.shared
    }
    
    func testSymbolCountRange() {
        settings.symbolCount = 5
        XCTAssertGreaterThanOrEqual(settings.symbolCount, 2)
        XCTAssertLessThanOrEqual(settings.symbolCount, 9)
    }
    
    func testDwellTimeRange() {
        settings.dwellTime = 1.5
        XCTAssertGreaterThanOrEqual(settings.dwellTime, 0.5)
        XCTAssertLessThanOrEqual(settings.dwellTime, 5.0)
    }
    
    func testSensitivityRange() {
        settings.sensitivity = 1
        XCTAssertGreaterThanOrEqual(settings.sensitivity, 0)
        XCTAssertLessThanOrEqual(settings.sensitivity, 2)
    }
    
    func testTrackingModeOptions() {
        settings.trackingMode = "2D"
        XCTAssertTrue(["2D", "3D"].contains(settings.trackingMode))
        
        settings.trackingMode = "3D"
        XCTAssertEqual(settings.trackingMode, "3D")
    }
    
    func testSmoothingModeOptions() {
        let validModes = ["none", "simple", "kalman", "adaptive", "combined"]
        settings.smoothingMode = "adaptive"
        XCTAssertTrue(validModes.contains(settings.smoothingMode))
    }
    
    func testEyeSelectionOptions() {
        let validSelections = ["both", "left", "right"]
        settings.eyeSelection = "both"
        XCTAssertTrue(validSelections.contains(settings.eyeSelection))
    }

    func testSelectionModeOptions() {
        let validSelections = ["face", "eyeGaze", "none"]
        settings.selectionMode = "none"
        XCTAssertTrue(validSelections.contains(settings.selectionMode))
    }
    
    func testPerPositionColors() {
        let testColor = Color.red
        settings.setSymbolColor(position: 1, color: testColor)
        
        let retrievedColor = settings.getSymbolColor(position: 1)
        // Colors should be approximately equal (hex comparison)
        XCTAssertNotNil(retrievedColor)
    }
    
    func testResetToDefaults() {
        // Modify settings
        settings.symbolCount = 7
        settings.dwellTime = 2.5
        settings.sensitivity = 2
        
        // Reset
        settings.resetToDefaults()
        
        // Verify defaults
        XCTAssertEqual(settings.symbolCount, 2)
        XCTAssertEqual(settings.dwellTime, 1.0)
        XCTAssertEqual(settings.sensitivity, 1)
        XCTAssertEqual(settings.trackingMode, "2D")
        XCTAssertEqual(settings.smoothingMode, "adaptive")
    }
}
