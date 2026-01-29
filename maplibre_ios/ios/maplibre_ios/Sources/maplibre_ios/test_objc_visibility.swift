import Foundation

// Test to see what selector name Swift generates
@objc(TestClass)
class TestClass: NSObject {
    @objc public static func getMapView(id: Int) -> String {
        return "Found"
    }
}

// Print the class
if let cls = NSClassFromString("TestClass") {
    print("Class found: \(cls)")
    
    // Try different selectors
    let selectors = ["getMapView:", "getMapViewWithId:", "getMapViewWithID:"]
    for sel in selectors {
        let selector = NSSelectorFromString(sel)
        if cls.responds(to: selector) {
            print("✅ Responds to: \(sel)")
        } else {
            print("❌ Does NOT respond to: \(sel)")
        }
    }
}
