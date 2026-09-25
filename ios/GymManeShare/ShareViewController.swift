import UIKit
import UniformTypeIdentifiers

/// Receives a shared plan (JSON or plain text), the same hand-off Android
/// gets from ACTION_SEND, and leaves it for the Flutter app to import.
final class ShareViewController: UIViewController {
  private let appGroup = "group.com.gymmane.app"
  private let incomingKey = "incoming_text"
  private var finished = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    ingest()
  }

  private func ingest() {
    let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
      .flatMap { $0.attachments ?? [] } ?? []
    load(providers, index: 0)
  }

  private func load(_ providers: [NSItemProvider], index: Int) {
    guard index < providers.count else {
      finish()
      return
    }
    let provider = providers[index]
    let types = [UTType.json, UTType.plainText, UTType.text, UTType.utf8PlainText, UTType.fileURL]
    guard let type = types.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) else {
      load(providers, index: index + 1)
      return
    }
    provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
      let text = Self.text(from: item)
      DispatchQueue.main.async {
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           text.utf8.count <= 2_000_000 {
          UserDefaults(suiteName: self.appGroup)?.set(text, forKey: self.incomingKey)
          self.openApp()
        } else {
          self.load(providers, index: index + 1)
        }
      }
    }
  }

  private func openApp() {
    guard let url = URL(string: "gymmane://incoming") else {
      finish()
      return
    }
    if openHost(url) {
      finish()
      return
    }
    extensionContext?.open(url, completionHandler: { _ in
      DispatchQueue.main.async { self.finish() }
    })
  }

  @discardableResult
  private func openHost(_ url: URL) -> Bool {
    var responder: UIResponder? = self
    let selector = sel_registerName("openURL:")
    while let current = responder {
      if current.responds(to: selector) {
        current.perform(selector, with: url)
        return true
      }
      responder = current.next
    }
    return false
  }

  private func finish() {
    guard !finished else { return }
    finished = true
    extensionContext?.completeRequest(returningItems: nil)
  }

  private static func text(from item: NSSecureCoding?) -> String? {
    if let text = item as? String { return text }
    if let url = item as? URL {
      if url.isFileURL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try? String(contentsOf: url, encoding: .utf8)
      }
      return nil
    }
    if let data = item as? Data, data.count <= 2_000_000 {
      return String(data: data, encoding: .utf8)
    }
    return nil
  }
}
