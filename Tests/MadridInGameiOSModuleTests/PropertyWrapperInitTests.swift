import XCTest
@testable import MadridInGameiOSModule

/// Regression: Xcode 27 rejects assigning a property wrapper (`self.x = ...` on `@State`/`@Published`)
/// before every stored property is initialised. Inits now set plain properties first and the wrapper
/// storage last; these tests pin that the values still land.
final class PropertyWrapperInitTests: XCTestCase {
    func testFloatingTextFieldViewModelKeepsAllInitValues() {
        let viewModel = FloatingTextFieldViewModel(text: "abc", placeholderText: "placeholder", isDescripcionTextfield: true)

        XCTAssertEqual(viewModel.text, "abc")
        XCTAssertEqual(viewModel.placeholderText, "placeholder")
        XCTAssertTrue(viewModel.isDescripcionTextfield)
    }
}
