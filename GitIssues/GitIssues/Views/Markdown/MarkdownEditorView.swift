//
//  MarkdownEditorView.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI
import WebKit

/// A view that provides a rich markdown editor using SimpleMDE
struct MarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        // Add message handler for receiving content from JavaScript
        contentController.add(context.coordinator, name: "contentChanged")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground") // Transparent background

        // Load the editor HTML
        let html = generateEditorHTML(placeholder: placeholder)
        webView.loadHTMLString(html, baseURL: nil)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Only update if the text has changed externally (not from the editor itself)
        if context.coordinator.lastKnownText != text && !context.coordinator.isUpdatingFromEditor {
            context.coordinator.lastKnownText = text
            let jsCode = """
                if (window.simplemde) {
                    window.simplemde.value(\(escapeForJavaScript(text)));
                }
            """
            webView.evaluateJavaScript(jsCode)
        }
    }

    private func escapeForJavaScript(_ string: String) -> String {
        let data = try! JSONEncoder().encode(string)
        return String(data: data, encoding: .utf8)!
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MarkdownEditorView
        var lastKnownText: String = ""
        var isUpdatingFromEditor = false

        init(_ parent: MarkdownEditorView) {
            self.parent = parent
            self.lastKnownText = parent.text
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "contentChanged", let content = message.body as? String {
                isUpdatingFromEditor = true
                lastKnownText = content
                DispatchQueue.main.async {
                    self.parent.text = content
                    // Reset the flag after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isUpdatingFromEditor = false
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Set initial content after the editor loads
            let jsCode = """
                if (window.simplemde) {
                    window.simplemde.value(\(parent.escapeForJavaScript(parent.text)));
                }
            """
            webView.evaluateJavaScript(jsCode)
        }
    }

    private func generateEditorHTML(placeholder: String) -> String {
        let escapedPlaceholder = placeholder.replacingOccurrences(of: "\"", with: "&quot;")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.css">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }

                html, body {
                    height: 100%;
                    overflow: hidden;
                }

                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
                    background: transparent;
                }

                .CodeMirror {
                    height: 100%;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.5;
                    border: none;
                    background: transparent;
                }

                .editor-toolbar {
                    background: rgba(0, 0, 0, 0.03);
                    border: none;
                    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
                }

                .editor-toolbar a {
                    color: #24292e !important;
                }

                .CodeMirror-scroll {
                    background: transparent;
                }

                /* Dark mode support */
                @media (prefers-color-scheme: dark) {
                    .editor-toolbar {
                        background: rgba(255, 255, 255, 0.05);
                        border-bottom-color: rgba(255, 255, 255, 0.1);
                    }

                    .editor-toolbar a {
                        color: #c9d1d9 !important;
                    }

                    .editor-toolbar a:hover {
                        background: rgba(255, 255, 255, 0.1);
                        border-color: rgba(255, 255, 255, 0.2);
                    }

                    .CodeMirror {
                        color: #c9d1d9;
                    }

                    .cm-s-paper .CodeMirror-code {
                        color: #c9d1d9;
                    }
                }

                #editor-container {
                    height: 100%;
                    display: flex;
                    flex-direction: column;
                }
            </style>
        </head>
        <body>
            <div id="editor-container">
                <textarea id="editor" placeholder="\(escapedPlaceholder)"></textarea>
            </div>

            <script src="https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.js"></script>
            <script>
                var simplemde = new SimpleMDE({
                    element: document.getElementById("editor"),
                    spellChecker: false,
                    placeholder: "\(escapedPlaceholder)",
                    status: false,
                    toolbar: [
                        "bold", "italic", "heading", "|",
                        "quote", "unordered-list", "ordered-list", "|",
                        "link", "image", "|",
                        "code", "table", "|",
                        "preview", "side-by-side", "fullscreen", "|",
                        "guide"
                    ],
                    autoDownloadFontAwesome: true
                });

                // Send changes to Swift
                simplemde.codemirror.on("change", function() {
                    var content = simplemde.value();
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.contentChanged) {
                        window.webkit.messageHandlers.contentChanged.postMessage(content);
                    }
                });

                // Make editor globally accessible
                window.simplemde = simplemde;

                // Refresh editor on window resize to ensure proper display
                window.addEventListener('resize', function() {
                    if (simplemde && simplemde.codemirror) {
                        simplemde.codemirror.refresh();
                    }
                });

                console.log('SimpleMDE editor initialized successfully');
            </script>
        </body>
        </html>
        """
    }
}
