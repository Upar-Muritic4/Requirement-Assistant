import SwiftUI
import Foundation

struct ContentView: View {
    @State private var selectedCSVURL: URL?
    @State private var markdownText: AttributedString = ""
    @State private var analysisText: AttributedString = {
        var attributedString = AttributedString("要件内容を分析します")
        attributedString.foregroundColor = NSColor.labelColor
        return attributedString
    }()
    @State private var fileName: String = "converted"

    var body: some View {
        VStack {
            Text("CSV to Markdown Converter Ver.0.13")
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
            .disabled(NSAttributedString(markdownText).length == 0)

            HSplitView {
                AttributedTextEditor(attributedText: $markdownText)
                    .padding()
                    .border(Color.gray, width: 1)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .layoutPriority(1)

                VSplitView {
                    AttributedTextEditor(attributedText: $analysisText)
                        .padding()
                        .border(Color.gray, width: 1)
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .layoutPriority(1)

                    AttributedTextEditor(attributedText: .constant({
                        var attributedString = AttributedString("要件改善を提案します")
                        attributedString.foregroundColor = NSColor.labelColor
                        return attributedString
                    }()))
                        .padding()
                        .border(Color.gray, width: 1)
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .layoutPriority(1)
                }
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
            summarizeMarkdown() // Summarize after converting

        } catch {
            markdownText = AttributedString("Error reading file: \(error.localizedDescription)")
        }
    }

    func summarizeMarkdown() {
        let fullText = NSAttributedString(markdownText).string
        let lines = fullText.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            analysisText = AttributedString("要約する内容がありません。")
            return
        }

        let projectName = fileName.replacingOccurrences(of: "要件定義書_", with: "")
        var summary = AttributedString("この要件定義書は、「\(projectName)」プロジェクトに関する詳細な要件を定義するものです。\n\n")

        var currentHeading = ""
        var contentByHeading: [String: [String]] = [:]

        for line in lines {
            if line.hasPrefix("#") {
                currentHeading = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                contentByHeading[currentHeading] = []
            } else if !currentHeading.isEmpty && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                contentByHeading[currentHeading]?.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        // Generate a more detailed, narrative summary
        if let purpose = contentByHeading.first(where: { $0.key.contains("目的") }) {
            let content = purpose.value.joined(separator: "。")
            summary.append(AttributedString("プロジェクトの根本的な目的として、「\(content)」が掲げられています。\n\n"))
        }

        if let overview = contentByHeading.first(where: { $0.key.contains("概要") }) {
            let content = overview.value.joined(separator: " ")
            summary.append(AttributedString("システム全体の概要については、「\(content)」と説明されています。\n\n"))
        }

        let functionalHeadings = contentByHeading.keys.filter { $0.contains("機能") }
        if !functionalHeadings.isEmpty {
            summary.append(AttributedString("主要な機能要件として、以下の項目が詳細に定義されています。\n"))
            for heading in functionalHeadings {
                if let content = contentByHeading[heading], !content.isEmpty {
                    var boldHeading = AttributedString("・\(heading): ")
                    boldHeading.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
                    summary.append(boldHeading)
                    
                    let details = content.joined(separator: "。")
                    summary.append(AttributedString("\(details)\n"))
                }
            }
            summary.append(AttributedString("\n"))
        }

        if let techSpecs = contentByHeading.first(where: { $0.key.contains("技術仕様") }) {
            summary.append(AttributedString("技術的な仕様に関しては、以下の具体的な指針が示されています。\n"))
            let content = techSpecs.value
            if !content.isEmpty {
                for item in content {
                    summary.append(AttributedString("  - \(item)\n"))
                }
            }
            summary.append(AttributedString("\n"))
        }
        
        let otherHeadings = contentByHeading.keys.filter {
            !$0.contains("目的") && !$0.contains("概要") && !$0.contains("機能") && !$0.contains("技術仕様")
        }

        if !otherHeadings.isEmpty {
            summary.append(AttributedString("その他、以下の点についても言及されています。\n"))
            for heading in otherHeadings {
                 if let content = contentByHeading[heading], !content.isEmpty {
                    var boldHeading = AttributedString("・\(heading): ")
                    boldHeading.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
                    summary.append(boldHeading)

                    let details = content.joined(separator: "。")
                    summary.append(AttributedString("\(details)\n"))
                }
            }
            summary.append(AttributedString("\n"))
        }

        summary.append(AttributedString("本定義書は、これらの要件を基に、関係者間の共通認識を形成し、プロジェクトを円滑に推進するための礎となります。"))

        summary.foregroundColor = NSColor.labelColor
        analysisText = summary
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
