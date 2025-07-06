import SwiftUI
import Foundation

struct ContentView: View {
    @State private var selectedCSVURL: URL?
    @State private var markdownText: AttributedString = ""
    @State private var analysisText: AttributedString = {
        var attributedString = AttributedString("Analysis Results will appear here")
        attributedString.foregroundColor = NSColor.labelColor
        return attributedString
    }()
    @State private var fileName: String = "converted"

    var body: some View {
        VStack {
            Text("CSV to Markdown Converter")
                .font(.title)
                .padding()

            HStack {
                Button("Select CSV File") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.commaSeparatedText]
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK {
                        if let url = panel.url {
                            self.selectedCSVURL = url
                            convertToMarkdown(url: url) // Convert immediately
                        }
                    }
                }
                if let url = selectedCSVURL {
                    Text(url.lastPathComponent)
                        .padding(.leading)
                }
            }
            .padding()

            Button("Save Markdown") {
                saveMarkdownToFile()
            }
            .padding()
            .disabled(NSAttributedString(markdownText).length == 0) // Disable if no text

            HSplitView {
                AttributedTextEditor(attributedText: $markdownText)
                    .padding()
                    .border(Color.gray, width: 1)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .layoutPriority(1)

                AttributedTextEditor(attributedText: $analysisText)
                    .padding()
                    .border(Color.gray, width: 1)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .layoutPriority(1)
            }
        }
        .padding()
    }

    func convertToMarkdown(url: URL) {
        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
            let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }

            guard lines.count >= 5 else {
                markdownText = AttributedString("CSV file must have at least 5 lines.")
                return
            }

            // 1. Extract filename from the 2nd row, 3rd column and store it
            let secondLineColumns = lines[1].components(separatedBy: ",")
            if secondLineColumns.count > 2 && secondLineColumns[1] == "要件定義書" {
                self.fileName = "要件定義書_" + secondLineColumns[2]
            } else {
                self.fileName = "converted"
            }

            var markdownOutput = AttributedString("")
            var justWroteHeading = false

            for i in 4..<lines.count {
                let row = lines[i].components(separatedBy: ",")
                guard row.count > 4 else { continue }

                let dai = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let chu = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
                let sho = row[3].trimmingCharacters(in: .whitespacesAndNewlines)
                let shosai = row[4].trimmingCharacters(in: .whitespacesAndNewlines)

                let hasDai = dai != "-" && !dai.isEmpty
                let hasChu = chu != "-" && !chu.isEmpty
                let hasSho = sho != "-" && !sho.isEmpty
                let hasShosai = shosai != "-" && !shosai.isEmpty

                let isHeadingRow = hasDai || hasChu || hasSho

                if isHeadingRow {
                    // Add blank line before a new heading, if needed
                    if NSAttributedString(markdownOutput).length > 0 {
                        markdownOutput.append(AttributedString("\n"))
                    }
                    if hasDai {
                        var attributedDai = AttributedString("# \(dai)\n")
                        attributedDai.foregroundColor = NSColor(red: 0/255, green: 136/255, blue: 255/255, alpha: 1.0)
                        markdownOutput.append(attributedDai)
                    }
                    if hasChu {
                        var attributedChu = AttributedString("## \(chu)\n")
                        attributedChu.foregroundColor = NSColor(red: 0/255, green: 136/255, blue: 255/255, alpha: 1.0)
                        markdownOutput.append(attributedChu)
                    }
                    if hasSho {
                        var attributedSho = AttributedString("### \(sho)\n")
                        attributedSho.foregroundColor = NSColor(red: 0/255, green: 136/255, blue: 255/255, alpha: 1.0)
                        markdownOutput.append(attributedSho)
                    }
                    justWroteHeading = true
                }

                if hasShosai {
                    var attributedShosai = AttributedString("\(shosai)\n")
                    attributedShosai.foregroundColor = NSColor.labelColor // System default text color
                    markdownOutput.append(attributedShosai)
                    justWroteHeading = false
                }
            }

            markdownText = markdownOutput

        } catch {
            markdownText = AttributedString("Error reading file: \(error.localizedDescription)")
        }
    }

    func saveMarkdownToFile() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.text]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "\(self.fileName).md"

        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                do {
                    try NSAttributedString(markdownText).string.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Error saving file: \(error.localizedDescription)")
                }
            }
        }
    }
}