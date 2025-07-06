import SwiftUI
import Foundation

struct ContentView: View {
    @State private var selectedCSVURL: URL?
    @State private var markdownText: AttributedString = ""
    @State private var analysisText: AttributedString = {
        var attributedString = AttributedString("要件内容を分析します")
        attributedString.foregroundColor = NSColor.white
        return attributedString
    }()
    @State private var suggestionText: AttributedString = {
        var attributedString = AttributedString("要件改善を提案します")
        attributedString.foregroundColor = NSColor.white
        return attributedString
    }()
    @State private var fileName: String = "converted"
    
    // For save confirmation alert
    @State private var showSaveConfirmation = false
    @State private var savedFilePath = ""

    var body: some View {
        VStack {
            Text("要件定義支援ツール Ver.0.14")
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

                    AttributedTextEditor(attributedText: $suggestionText)
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
        .alert("保存完了", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("ファイルは以下の場所に保存されました：\n\(savedFilePath)")
        }
    }

    func convertToMarkdown(url: URL) {
        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
            let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }

            guard lines.count >= 5 else {
                markdownText = AttributedString("CSV file must have at least 5 lines.")
                return
            }

            let secondLineColumns = lines[1].components(separatedBy: ",")
            if secondLineColumns.count > 2 && secondLineColumns[1] == "要件定義書" {
                self.fileName = "要件定義書_" + secondLineColumns[2]
            } else {
                self.fileName = "converted"
            }

            var markdownOutput = AttributedString("")
            let blueColor = NSColor(red: 0/255, green: 128/255, blue: 255/255, alpha: 1.0)

            for i in 4..<lines.count {
                let row = lines[i].components(separatedBy: ",")
                guard row.count > 4 else { continue }

                let dai = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let chu = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
                let sho = row[3].trimmingCharacters(in: .whitespacesAndNewlines)
                let shosai = row[4].trimmingCharacters(in: .whitespacesAndNewlines)

                if !dai.isEmpty && dai != "-" {
                    markdownOutput.append(AttributedString("\n# \(dai)\n", attributes: AttributeContainer().foregroundColor(blueColor)))
                }
                if !chu.isEmpty && chu != "-" {
                    markdownOutput.append(AttributedString("\n## \(chu)\n", attributes: AttributeContainer().foregroundColor(blueColor)))
                }
                if !sho.isEmpty && sho != "-" {
                    markdownOutput.append(AttributedString("\n### \(sho)\n", attributes: AttributeContainer().foregroundColor(blueColor)))
                }
                if !shosai.isEmpty && shosai != "-" {
                    markdownOutput.append(AttributedString("\(shosai)\n", attributes: AttributeContainer().foregroundColor(NSColor.white)))
                }
            }

            markdownText = markdownOutput
            summarizeMarkdown()

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
        var summaryString = "この要件定義書は、「\(projectName)」プロジェクトに関する詳細な要件を定義するものです。\n\n"

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

        if let purpose = contentByHeading.first(where: { $0.key.contains("目的") }) {
            summaryString += "プロジェクトの目的: \(purpose.value.joined(separator: "。 "))\n"
        }
        if let overview = contentByHeading.first(where: { $0.key.contains("概要") }) {
            summaryString += "システムの概要: \(overview.value.joined(separator: "。 "))\n\n"
        }

        let functionalHeadings = contentByHeading.keys.filter { $0.contains("機能") }
        if !functionalHeadings.isEmpty {
            summaryString += "主な機能要件：\n"
            for heading in functionalHeadings {
                if let content = contentByHeading[heading], !content.isEmpty {
                    summaryString += "・\(heading): \(content.joined(separator: ", "))\n"
                }
            }
            summaryString += "\n"
        }

        generateSuggestions(contentByHeading: contentByHeading)
        analysisText = AttributedString(summaryString, attributes: AttributeContainer().foregroundColor(NSColor.white))
    }

    func generateSuggestions(contentByHeading: [String: [String]]) {
        var suggestionsString = ""
        let missingSections = ["非機能要件", "制約条件", "性能要件", "セキュリティ要件"].filter {
            !contentByHeading.keys.contains($0)
        }

        if missingSections.isEmpty {
            suggestionsString = "改善案はありません。"
        } else {
            suggestionsString += "以下の点を追記すると、より明確な要件定義になります.\n"
            for section in missingSections {
                suggestionsString += "・\(section)\n"
            }
        }
        suggestionText = AttributedString(suggestionsString, attributes: AttributeContainer().foregroundColor(NSColor.white))
    }

    func saveMarkdownToFile() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error: Could not find the user's Documents directory.")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("\(self.fileName).md")
        
        do {
            let markdownString = NSAttributedString(markdownText).string
            try markdownString.write(to: fileURL, atomically: true, encoding: .utf8)
            
            self.savedFilePath = fileURL.path
            self.showSaveConfirmation = true
            
        } catch {
            print("Error saving file: \(error.localizedDescription)")
            // Here you might want to show an error alert to the user
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
