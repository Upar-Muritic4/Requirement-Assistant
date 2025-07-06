import SwiftUI
import Foundation
import UniformTypeIdentifiers

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
            Text("要件定義支援ツール Ver.0.15")
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

            HStack {
                Button("マークダウン形式の要件定義を保存する") {
                    saveMarkdownToFile()
                }
                .padding()
                .disabled(NSAttributedString(markdownText).length == 0)

                Button("要件定義の要約情報を保存する") {
                    saveSummaryToFile()
                }
                .padding()
                .disabled(NSAttributedString(analysisText).length == 0 || NSAttributedString(analysisText).string == "要件内容を分析します")
            }

            HSplitView {
                AttributedTextEditor(attributedText: $markdownText, isEditable: false)
                    .padding()
                    .border(Color.gray, width: 1)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .layoutPriority(1)

                VSplitView {
                    AttributedTextEditor(attributedText: $analysisText, isEditable: false)
                        .padding()
                        .border(Color.gray, width: 1)
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .layoutPriority(1)

                    AttributedTextEditor(attributedText: $suggestionText, isEditable: false)
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

    private func getFirstContent(for keys: [String], contentByHeading: [String: [String]]) -> String {
        for key in keys {
            if let value = contentByHeading.first(where: { $0.key.contains(key) })?.value {
                let content = value.map { $0.replacingOccurrences(of: "```", with: "") }
                                   .joined(separator: "。 ")
                                   .trimmingCharacters(in: .whitespacesAndNewlines)
                if !content.isEmpty {
                    return content
                }
            }
        }
        return "記載がありません"
    }

    private func getAllContent(for keys: [String], excluding: [String] = [], contentByHeading: [String: [String]]) -> String {
        var allMatchingHeadings = Set<String>()
        for key in keys {
            let matchingHeadings = contentByHeading.keys.filter { heading in
                let includeMatch = heading.contains(key)
                let excludeMatch = excluding.contains { heading.contains($0) }
                return includeMatch && !excludeMatch
            }
            for heading in matchingHeadings {
                allMatchingHeadings.insert(heading)
            }
        }

        if allMatchingHeadings.isEmpty {
            return "記載がありません"
        }

        var result = ""
        for heading in allMatchingHeadings.sorted() {
            if let content = contentByHeading[heading], !content.isEmpty {
                let cleanedContent = content.map { $0.replacingOccurrences(of: "```", with: "") }
                                           .joined(separator: ", ")
                                           .trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanedContent.isEmpty {
                    result += "・\(heading): \(cleanedContent)\n"

                }
            }
        }
        return result.isEmpty ? "記載がありません" : result
    }

    private func getRawContentForHeading(for keys: [String], contentByHeading: [String: [String]]) -> String {
        for key in keys {
            if let matchingHeading = contentByHeading.keys.first(where: { $0.contains(key) }) {
                if let content = contentByHeading[matchingHeading] {
                    let cleanedContent = content.map { $0.replacingOccurrences(of: "```", with: "") }
                                               .joined(separator: "\n") // Preserve newlines
                                               .trimmingCharacters(in: .whitespacesAndNewlines)
                    return cleanedContent.isEmpty ? "記載がありません" : cleanedContent
                }
            }
        }
        return "記載がありません"
    }

    func summarizeMarkdown() {
        let fullText = NSAttributedString(markdownText).string
        let lines = fullText.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            analysisText = AttributedString("要約する内容がありません。")
            return
        }

        var contentByHeading: [String: [String]] = [:]
        var currentHeading = ""

        for line in lines {
            if line.hasPrefix("#") {
                currentHeading = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                contentByHeading[currentHeading] = []
            } else if !currentHeading.isEmpty && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                contentByHeading[currentHeading]?.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        let projectName = fileName.replacingOccurrences(of: "要件定義書_", with: "")
        let purpose = getFirstContent(for: ["目的"], contentByHeading: contentByHeading)
        let people = getFirstContent(for: ["関係者", "体制", "登場人物"], contentByHeading: contentByHeading)
        let functionalRequirements: String = getAllContent(for: ["機能"], contentByHeading: contentByHeading)
        let nonFunctionalRequirements: String = getAllContent(for: ["非機能", "性能要求", "品質要求", "互換性要求", "保守性要求"], contentByHeading: contentByHeading)
        let techSpecs: String = getAllContent(for: ["技術仕様", "動作環境", "必要なソフトウェア", "スクリプトファイル仕様", "コマンド実行順序"], contentByHeading: contentByHeading)
        let constraints: String = getAllContent(for: ["制約", "前提条件", "技術的制約", "コンテンツ制約"], contentByHeading: contentByHeading)
        let deliverables: String = getAllContent(for: ["成果物", "納品物", "生成物"], excluding: ["中間"], contentByHeading: contentByHeading)
        let qa: String = getAllContent(for: ["テスト", "チェックポイント", "エラー処理"], contentByHeading: contentByHeading)
        let scalability: String = getAllContent(for: ["拡張", "展開", "将来的な拡張", "カスタマイズポイント"], contentByHeading: contentByHeading)

        // Summaries for human-readable output
        var techSpecsSummary: String
        if techSpecs == "記載がありません" {
            techSpecsSummary = "開発に必要な技術仕様については、特に記載がありません。"
        } else {
            techSpecsSummary = "開発に必要な技術仕様は以下の通りです。\n" + techSpecs
        }

        var constraintsSummary: String
        if constraints == "記載がありません" {
            constraintsSummary = "制約事項については、特に記載がありません。"
        } else {
            constraintsSummary = "制約事項として以下の内容が挙げられています。\n" + constraints
        }

        var deliverablesSummary: String
        if deliverables == "記載がありません" {
            deliverablesSummary = "成果物については、特に記載がありません。"
        } else {
            deliverablesSummary = "成果物は以下の通りです。\n" + deliverables
        }

        var qaSummary: String
        if qa == "記載がありません" {
            qaSummary = "開発後の品質保証については、特に方針の記載がありません。"
        } else {
            qaSummary = "開発後の品質保証は、以下の方針で進められます。\n" + qa
        }

        var scalabilitySummary: String
        if scalability == "記載がありません" {
            scalabilitySummary = "将来的な拡張性については、特に記載がありません。"
        } else {
            scalabilitySummary = "将来的な拡張性として、以下の点が考慮されています。\n" + scalability
        }

        // Handle System Configuration
        let directoryStructureContent = getRawContentForHeading(for: ["ディレクトリ構造"], contentByHeading: contentByHeading)
        let processingFlowContent = getFirstContent(for: ["処理フロー"], contentByHeading: contentByHeading)

        var systemConfigSummary: String
        if directoryStructureContent == "記載がありません" && processingFlowContent == "記載がありません" {
            systemConfigSummary = "最終的なシステム構成については、特に記載がありません。"
        } else {
            systemConfigSummary = "最終的なシステム構成は以下の通りです。\n"
            if directoryStructureContent != "記載がありません" {
                systemConfigSummary += "・ディレクトリ構造:\n" + directoryStructureContent.components(separatedBy: "\n").map { "    " + $0 }.joined(separator: "\n") + "\n"
            }
            if processingFlowContent != "記載がありません" {
                systemConfigSummary += "・処理フロー: \(processingFlowContent)\n"
            }
        }

        var summaryString = ""
        summaryString += "この要件定義は「\(projectName)」プロジェクトに関するもので、\n"
        summaryString += "目的は「\(purpose)」であり、\n"
        summaryString += "関わる人は「\(people)」です。\n\n"
        summaryString += "機能要件は以下の通りです。\n"
        summaryString += String(functionalRequirements)
        summaryString += "\n非機能要件は以下の通りです。\n"
        summaryString += String(nonFunctionalRequirements)
        summaryString += "\n" + techSpecsSummary
        summaryString += "\n" + constraintsSummary
        summaryString += "\n" + systemConfigSummary
        summaryString += "\n" + deliverablesSummary
        summaryString += "\n" + qaSummary
        summaryString += "\n" + scalabilitySummary

        analysisText = AttributedString(summaryString, attributes: AttributeContainer().foregroundColor(NSColor.white))
        generateSuggestions(contentByHeading: contentByHeading)
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
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText]
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = "\(self.fileName).md"

            if panel.runModal() == .OK {
                guard let url = panel.url else {
                    print("Error: Could not get save URL.")
                    return
                }
                do {
                    let markdownString = NSAttributedString(markdownText).string
                    try markdownString.write(to: url, atomically: true, encoding: .utf8)
                    
                    self.savedFilePath = url.path
                    self.showSaveConfirmation = true
                    
                } catch {
                    print("Error saving file: \(error.localizedDescription)")
                    // Here you might want to show an error alert to the user
                }
            }
        }
    }
    func saveSummaryToFile() {
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText]
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = "\(self.fileName)_要約.txt"

            if panel.runModal() == .OK {
                guard let url = panel.url else {
                    print("Error: Could not get save URL.")
                    return
                }
                do {
                    let summaryString = NSAttributedString(analysisText).string
                    try summaryString.write(to: url, atomically: true, encoding: .utf8)
                    
                    self.savedFilePath = url.path
                    self.showSaveConfirmation = true
                    
                } catch {
                    print("Error saving file: \(error.localizedDescription)")
                    // Here you might want to show an error alert to the user
                }
            }
        }
    }
    static var previews: some View {
        ContentView()
    }
}
