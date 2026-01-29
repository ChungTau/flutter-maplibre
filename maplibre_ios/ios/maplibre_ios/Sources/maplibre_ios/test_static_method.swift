import Foundation

@objc(TestClass)
class TestClass: NSObject {
    @objc public static func getMapView(id: Int) -> String {
        return "Found with id: \(id)"
    }
}

if let cls = NSClassFromString("TestClass") {
    print("Class found: \(cls)")
    
    let selector = NSSelectorFromString("getMapViewWithId:")
    
    // Check if class responds (this checks instance methods)
    print("cls.responds(to:) = \(cls.responds(to: selector))")
    
    // Check if the class object (metaclass) responds (for static methods)
    let metaclass: AnyClass = object_getClass(cls)!
    print("metaclass.responds(to:) = \(metaclass.responds(to: selector))")
    
    // Try to call it
    if metaclass.responds(to: selector) {
        let method = class_getClassMethod(cls, selector)!
        let imp = method_getImplementation(method)
        typealias Function = @convention(c) (AnyClass, Selector, Int) -> AnyObject
        let call = unsafeBitCast(imp, to: Function.self)
        let result = call(cls, selector, 123)
        print("Result: \(result)")
    }
}
