import SwiftUI
import UIKit

/// Drop-in replacement for SwiftUI's `TextField` that places the cursor at
/// the end of existing text the moment it becomes focused, instead of
/// leaving it wherever the tap landed. Stock `TextField` has no supported
/// way to control cursor placement, so this wraps `UITextField` directly.
///
/// Not usable inside `.alert()` — SwiftUI builds alert text fields itself
/// from a `UIAlertController`, so there's no view to substitute there.
struct CursorEndTextField: UIViewRepresentable {
    enum Style {
        case plain
        case money(Font.TextStyle = .body)
    }

    var placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var alignment: TextAlignment = .leading
    var style: Style = .plain
    var autocapitalization: UITextAutocapitalizationType = .sentences
    var autocorrection: UITextAutocorrectionType = .default

    @Environment(\.isEnabled) private var isEnabled

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.text = $text
        if field.text != text { field.text = text }
        field.placeholder = placeholder
        field.keyboardType = keyboardType
        field.textAlignment = uiAlignment
        field.autocapitalizationType = autocapitalization
        field.autocorrectionType = autocorrection
        field.isEnabled = isEnabled
        field.font = uiFont
        field.textColor = isEnabled ? .label : .tertiaryLabel
        field.adjustsFontForContentSizeCategory = true
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    private var uiAlignment: NSTextAlignment {
        switch alignment {
        case .leading: .natural
        case .trailing: .right
        case .center: .center
        }
    }

    private var uiFont: UIFont {
        switch style {
        case .plain:
            return UIFont.preferredFont(forTextStyle: .body)
        case .money(let textStyle):
            let base = UIFont.preferredFont(forTextStyle: textStyle.uiTextStyle)
            let monoDigitSemibold = UIFont.monospacedDigitSystemFont(ofSize: base.pointSize, weight: .semibold)
            let rounded = monoDigitSemibold.fontDescriptor.withDesign(.rounded) ?? monoDigitSemibold.fontDescriptor
            return UIFont(descriptor: rounded, size: monoDigitSemibold.pointSize)
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        @objc func editingChanged(_ field: UITextField) {
            text.wrappedValue = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            // Setting the range during the same pass that grants first
            // responder gets overwritten by UIKit's own default placement,
            // so push it to the next runloop turn.
            DispatchQueue.main.async {
                let end = field.endOfDocument
                field.selectedTextRange = field.textRange(from: end, to: end)
            }
        }
    }
}

private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .subheadline: .subheadline
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
}
