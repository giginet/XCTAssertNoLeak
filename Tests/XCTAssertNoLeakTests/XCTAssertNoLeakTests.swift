import XCTest
@testable import XCTAssertNoLeak

final class XCTAssertNoLeakTests: XCTestCase {
    func assertMessages(_ object: @autoclosure () -> AnyObject) -> [String] {
        var result = [String]()
        assertNoLeak(object(), assert: { message, _, _ in result.append(message) }, file: "", line: 0)
        return result
    }
    
    func assertMessages(_ f: @escaping (Context) -> ()) -> [String] {
        var result = [String]()
        assertNoLeak(f, assert: { message, _, _ in result.append(message) }, file: "", line: 0)
        return result
    }
    
    func testAssertNoLeak() {
        class AssertNoLeakObject {
            var id: Int = 0
            var name: String = "name"
            var children: [AssertNoLeakObject] = []
        }
        XCTAssertEqual(
            assertMessages(AssertNoLeakObject()),
            []
        )
    }
    
    func testAssertMemoryLeak() {
        class MemoryLeakObject {
            var strongSelf: MemoryLeakObject!
            init() { strongSelf = self }
        }
        XCTAssertEqual(
            assertMessages(MemoryLeakObject()),
            [makeAssertMessage(path: "self")]
        )
    }
    
    func testAssertWeakDelegate() {
        #if swift(>=4.2)
            #if compiler(>=5.0)
            #else
            print("This test case is unavailable: https://bugs.swift.org/browse/SR-8878")
            return
            #endif
        #endif
        class ChildObject {
            weak var delegate: ParentObject?
        }
        class ParentObject {
            var child: ChildObject
            
            init() {
                child = ChildObject()
                child.delegate = self
            }
        }
        XCTAssertEqual(
            assertMessages(ParentObject()),
            []
        )
    }
    
    func testAssertStrongDelegate() {
        class ChildObject {
            var delegate: ParentObject?
        }
        class ParentObject {
            var child: ChildObject
            
            init() {
                child = ChildObject()
                child.delegate = self
            }
        }
        class RootObject {
            let parent = ParentObject()
        }
        XCTAssertEqual(
            assertMessages(RootObject()),
            [
                makeAssertMessage(path: "self.parent")
            ]
        )
    }
    
    func testAssertOptionalProperty() {
        class ChildObject {
            var strongDelegate: ParentObject?
        }
        class ParentObject {
            var child: ChildObject
            
            init() {
                child = ChildObject()
                child.strongDelegate = self
            }
        }
        
        class RootObject {
            let parent: ParentObject? = ParentObject()
        }
        XCTAssertEqual(
            assertMessages(RootObject()),
            [
                makeAssertMessage(path: "self.parent?")
            ]
        )
    }
    
    func testAssertLazyProperty() {
        class ChildObject {
            var strongDelegate: ParentObject?
        }
        class ParentObject {
            var child: ChildObject
            
            init() {
                child = ChildObject()
                child.strongDelegate = self
            }
        }
        class RootObject {
            lazy var parent = ParentObject()
            
            init() {
                parent = ParentObject()
            }
        }
        XCTAssertEqual(
            assertMessages(RootObject()),
            [
                makeAssertMessage(path: "self.parent")
            ]
        )
    }
    
    func testAssertClosure() {
        class View {
            var strongDelegate: AnyObject?
        }
        class ViewController {
            lazy var view: View = self.loadView()
            func loadView() -> View {
                let view = View()
                view.strongDelegate = self
                return view
            }
        }
        XCTAssertEqual(
            assertMessages { context in
                let vc = ViewController()
                context.traverse(name: "vc", object: vc)
            },
            ["context.completion() must call"]
        )
        XCTAssertEqual(
            assertMessages { context in
                let vc = ViewController()
                context.traverse(name: "vc", object: vc)
                context.completion()
            },
            []
        )
        XCTAssertEqual(
            assertMessages { context in
                let vc = ViewController()
                _ = vc.view // load view
                context.traverse(name: "vc", object: vc)
                context.completion()
            },
            [
                makeAssertMessage(path: "vc")
            ]
        )
    }
    
    func testAssertIgnoreSingleton() {
        class Singleton: CustomTraversable {
            static let shared = Singleton()
            var ignoreAssertion: Bool { return true }
        }
        class View {
            let sharedObjectPath = Singleton.shared
        }
        XCTAssertEqual(
            assertMessages(View()),
            []
        )
    }

    static var allTests = [
        ("testAssertNoLeak", testAssertNoLeak),
        ("testAssertMemoryLeak", testAssertMemoryLeak),
        ("testAssertWeakDelegate", testAssertWeakDelegate),
        ("testAssertStrongDelegate", testAssertStrongDelegate),
        ("testAssertOptionalProperty", testAssertOptionalProperty),
        ("testAssertLazyProperty", testAssertLazyProperty),
        ("testAssertClosure", testAssertClosure),
    ]
}
