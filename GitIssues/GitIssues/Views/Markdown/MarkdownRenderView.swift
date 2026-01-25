//
//  MarkdownRenderView.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI
import WebKit

/// A view that renders markdown content using GitHub's markdown API
struct MarkdownRenderView: View {
    let markdown: String
    let apiService: GitHubAPIService

    @State private var renderedHTML: String?
    @State private var isLoading = true
    @State private var error: String?
    @State private var contentHeight: CGFloat = 100

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                Text("Failed to render markdown: \(error)")
                    .foregroundColor(.secondary)
                    .padding()
            } else if let html = renderedHTML {
                MarkdownWebView(html: html, contentHeight: $contentHeight)
                    .frame(height: contentHeight)
            }
        }
        .task {
            await loadMarkdown()
        }
    }

    private func loadMarkdown() async {
        guard !markdown.isEmpty else {
            renderedHTML = ""
            isLoading = false
            return
        }

        do {
            let html = try await apiService.renderMarkdown(markdown)
            renderedHTML = wrapHTML(html)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    /// Wraps the GitHub-rendered HTML with styling
    private func wrapHTML(_ html: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.5;
                    color: #24292e;
                    padding: 0;
                    margin: 0;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #c9d1d9;
                        background: transparent;
                    }
                    a { color: #58a6ff; }
                    code, pre {
                        background-color: rgba(110, 118, 129, 0.4);
                        color: #c9d1d9;
                    }
                    blockquote {
                        border-left-color: #3b434b;
                        color: #8b949e;
                    }
                }
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 24px;
                    margin-bottom: 16px;
                    font-weight: 600;
                    line-height: 1.25;
                }
                h1 { font-size: 2em; border-bottom: 1px solid #e1e4e8; padding-bottom: 0.3em; }
                h2 { font-size: 1.5em; border-bottom: 1px solid #e1e4e8; padding-bottom: 0.3em; }
                h3 { font-size: 1.25em; }
                h4 { font-size: 1em; }
                h5 { font-size: 0.875em; }
                h6 { font-size: 0.85em; color: #6a737d; }
                p { margin-top: 0; margin-bottom: 16px; }
                code {
                    padding: 0.2em 0.4em;
                    margin: 0;
                    font-size: 85%;
                    background-color: rgba(27, 31, 35, 0.05);
                    border-radius: 3px;
                    font-family: "SF Mono", Monaco, Consolas, monospace;
                }
                pre {
                    padding: 16px;
                    overflow: auto;
                    font-size: 85%;
                    line-height: 1.45;
                    background-color: #f6f8fa;
                    border-radius: 6px;
                    font-family: "SF Mono", Monaco, Consolas, monospace;
                }
                pre code {
                    display: inline;
                    padding: 0;
                    margin: 0;
                    overflow: visible;
                    line-height: inherit;
                    background-color: transparent;
                    border: 0;
                }
                blockquote {
                    padding: 0 1em;
                    color: #6a737d;
                    border-left: 0.25em solid #dfe2e5;
                    margin: 0 0 16px 0;
                }
                ul, ol {
                    padding-left: 2em;
                    margin-top: 0;
                    margin-bottom: 16px;
                }
                li + li { margin-top: 0.25em; }
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 6px;
                }
                table {
                    border-spacing: 0;
                    border-collapse: collapse;
                    margin-bottom: 16px;
                }
                table th, table td {
                    padding: 6px 13px;
                    border: 1px solid #d0d7de;
                }
                table th {
                    font-weight: 600;
                    background-color: #f6f8fa;
                }
                table tr {
                    background-color: #ffffff;
                    border-top: 1px solid #d0d7de;
                }
                table tr:nth-child(2n) {
                    background-color: #f6f8fa;
                }
                a {
                    color: #0969da;
                    text-decoration: none;
                }
                a:hover {
                    text-decoration: underline;
                }
                hr {
                    height: 0.25em;
                    padding: 0;
                    margin: 24px 0;
                    background-color: #e1e4e8;
                    border: 0;
                }
                input[type="checkbox"] {
                    margin: 0 0.5em 0 0;
                }
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """
    }
}

/// WKWebView wrapper for displaying HTML with auto-height
struct MarkdownWebView: NSViewRepresentable {
    let html: String
    @Binding var contentHeight: CGFloat

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // Transparent background
        webView.navigationDelegate = context.coordinator

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.contentHeight = $contentHeight
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var contentHeight: Binding<CGFloat>

        init(contentHeight: Binding<CGFloat>) {
            self.contentHeight = contentHeight
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Calculate content height after page loads
            webView.evaluateJavaScript("document.body.scrollHeight") { result, error in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        // Add 25px buffer to prevent content cutoff
                        self.contentHeight.wrappedValue = max(height + 25, 60)
                    }
                }
            }
        }
    }
}
