import SwiftUI
import Foundation
import UniformTypeIdentifiers

/// メインのコンテンツビューを定義する構造体
struct ContentView: View {
    /// ユーザーが選択したCSVファイルのURLを保持するState
    @State private var selectedCSVURL: URL?
    /// CSVから変換されたMarkdownテキストを保持するState
    @State private var markdownText: AttributedString = ""
    /// 要件定義の要約テキストを保持するState
    @State private var analysisText: AttributedString = {
        var attributedString = AttributedString("要件内容を分析します")
        attributedString.foregroundColor = NSColor.white
        return attributedString
    }()
    /// 改善提案テキストを保持するState
    @State private var suggestionText: AttributedString = {
        var attributedString = AttributedString("要件改善を提案します")
        attributedString.foregroundColor = NSColor.white
        return attributedString
    }()
    /// 保存時のファイル名を保持するState
    @State private var fileName: String = "converted"
    
    /// 保存完了アラートの表示状態を制御するState
    @State private var showSaveConfirmation = false
    /// 保存されたファイルのパスを保持するState
    @State private var savedFilePath = ""

    /// アプリケーションのメインUIを構築するBodyプロパティ
    var body: some View {
        VStack {
            Text("要件定義支援ツール Ver.0.16")
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

            // メインコンテンツ領域を水平に分割
            HSplitView {
                // 左側の要件定義データ表示エリア
                VStack {
                    Text("要件定義データ")
                        .font(.headline)
                        .bold()
                        .padding(.bottom, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    AttributedTextEditor(attributedText: $markdownText, isEditable: false)
                }
                .padding()
                .border(Color.gray, width: 1)
                .frame(minWidth: 0, maxWidth: .infinity)
                .layoutPriority(1)

                // 右側の要約と改善ポイント表示エリアを垂直に分割
                VSplitView {
                    // 右上：要件内容の要約表示エリア
                    VStack {
                        Text("要件内容の要約")
                            .font(.headline)
                            .bold()
                            .padding(.bottom, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        AttributedTextEditor(attributedText: $analysisText, isEditable: false)
                    }
                    .padding()
                    .border(Color.gray, width: 1)
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .layoutPriority(1)

                    // 右下：改善ポイント表示エリア
                    VStack {
                        Text("改善ポイント")
                            .font(.headline)
                            .bold()
                            .padding(.bottom, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        AttributedTextEditor(attributedText: $suggestionText, isEditable: false)
                    }
                    .padding()
                    .border(Color.gray, width: 1)
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .layoutPriority(1)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .layoutPriority(1)
            } // End of HSplitView
        }
        .padding()
        .alert("保存完了", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("ファイルは以下の場所に保存されました：\n\(savedFilePath)")
        }
    }

    /// 指定されたURLのCSVファイルを読み込み、Markdown形式に変換して表示する
    /// - Parameter url: 変換対象のCSVファイルのURL
    func convertToMarkdown(url: URL) {
        do {
            // CSVファイルをUTF-8エンコーディングで文字列として読み込む
            let csvString = try String(contentsOf: url, encoding: .utf8)
            // 各行に分割し、空行を除外
            let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }

            // CSVファイルの行数チェック
            guard lines.count >= 5 else {
                markdownText = AttributedString("CSV file must have at least 5 lines.")
                return
            }

            // ファイル名決定ロジック
            let secondLineColumns = lines[1].components(separatedBy: ",")
            if secondLineColumns.count > 2 && secondLineColumns[1] == "要件定義書" {
                self.fileName = "要件定義書_" + secondLineColumns[2]
            } else {
                self.fileName = "converted"
            }

            var markdownOutput = AttributedString("")
            // 青色の定義をループの外に移動し、効率化
            let blueColor = NSColor(red: 0/255, green: 128/255, blue: 255/255, alpha: 1.0)

            // CSVの各行をMarkdown形式に変換
            for i in 4..<lines.count {
                let row = lines[i].components(separatedBy: ",")
                // 行の列数チェック
                guard row.count > 4 else { continue }

                // 各列のデータをトリミング
                let dai = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let chu = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
                let sho = row[3].trimmingCharacters(in: .whitespacesAndNewlines)
                let shosai = row[4].trimmingCharacters(in: .whitespacesAndNewlines)

                // 大項目（#）の追加
                if !dai.isEmpty && dai != "-" {
                    markdownOutput.append(AttributedString("\n# \(dai)\n", attributes: AttributeContainer().foregroundColor(blueColor)))
                }
                // 中項目（##）の追加
                if !chu.isEmpty && chu != "-" {
                    markdownOutput.append(AttributedString("\n## \(chu)\n", attributes: AttributeContainer().foregroundColor(blueColor)))
                }
                // 小項目（###）の追加
                if !sho.isEmpty && sho != "-" {
                    markdownOutput.append(AttributedString("\n### \(sho)\n", attributes: AttributeContainer().foregroundColor(blueColor)))
                }
                // 詳細内容の追加
                if !shosai.isEmpty && shosai != "-" {
                    markdownOutput.append(AttributedString("\(shosai)\n", attributes: AttributeContainer().foregroundColor(NSColor.white)))
                }
            }

            // 変換結果をMarkdownテキストとして設定
            markdownText = markdownOutput
            print("markdownText updated. Length: \(NSAttributedString(markdownText).length)")
            // Markdownから要約を生成
            summarizeMarkdown()

        } catch {
            // ファイル読み込みエラー時の処理
            markdownText = AttributedString("Error reading file: \(error.localizedDescription)")
            print("Error in convertToMarkdown: \(error.localizedDescription)")
        }
    }
    }

    /// 指定されたキーに合致する最初の見出しの内容を取得するヘルパー関数
    /// - Parameters:
    ///   - keys: 検索するキーワードの配列
    ///   - contentByHeading: 見出しと内容の辞書
    /// - Returns: 合致した見出しの内容、または「記載がありません」
    private func getFirstContent(for keys: [String], contentByHeading: [String: [String]]) -> String {
        for key in keys {
            if let value = contentByHeading.first(where: { $0.key.contains(key) })?.value {
                let content = _cleanContent(value.joined(separator: "。 "))
                if !content.isEmpty {
                    return content
                }
            }
        }
        return "記載がありません"
    }

    /// 指定されたキーに合致するすべての見出しの内容を取得するヘルパー関数
    /// - Parameters:
    ///   - keys: 検索するキーワードの配列
    ///   - excluding: 除外するキーワードの配列
    ///   - contentByHeading: 見出しと内容の辞書
    /// - Returns: 合致したすべての見出しの内容を結合した文字列、または「記載がありません」
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
                let cleanedContent = _cleanContent(content.joined(separator: ", "))
                if !cleanedContent.isEmpty {
                    result += "・\(heading): \(cleanedContent)\n"

                }
            }
        }
        return result.isEmpty ? "記載がありません" : result
    }

    /// 指定されたキーに合致する見出しの生の内容（改行保持）を取得するヘルパー関数
    /// - Parameters:
    ///   - keys: 検索するキーワードの配列
    ///   - contentByHeading: 見出しと内容の辞書
    /// - Returns: 合致した見出しの生の内容、または「記載がありません」
    private func getRawContentForHeading(for keys: [String], contentByHeading: [String: [String]]) -> String {
        for key in keys {
            if let matchingHeading = contentByHeading.keys.first(where: { $0.contains(key) }) {
                if let content = contentByHeading[matchingHeading] {
                    let cleanedContent = _cleanContent(content.joined(separator: "\n")) // Preserve newlines
                    return cleanedContent.isEmpty ? "記載がありません" : cleanedContent
                }
            }
        }
        return "記載がありません"
    }

    /// 文字列からMarkdownのコードブロック記号と不要な空白を除去するプライベートヘルパー関数
    /// - Parameter text: 処理対象の文字列
    /// - Returns: クリーンアップされた文字列
    private func _cleanContent(_ text: String) -> String {
        return text.replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Markdownテキストを解析し、要約と改善提案を生成する
    /// 要約セクションのフォーマットを共通化するヘルパー関数
    /// - Parameters:
    ///   - content: セクションの内容
    ///   - sectionName: セクションの名称
    ///   - prefix: 内容がある場合の前置き文
    /// - Returns: フォーマットされた要約文字列
    private func _formatSummarySection(content: String, sectionName: String, prefix: String) -> String {
        if content == "記載がありません" {
            return "\(sectionName)については、特に記載がありません。"
        } else {
            return "\(prefix)\n" + content
        }
    }

    /// Markdownテキストを解析し、要約と改善提案を生成する
    func summarizeMarkdown() {
        // Markdownテキストを文字列に変換し、行ごとに分割して空行を除外
        let fullText = NSAttributedString(markdownText).string
        let lines = fullText.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // テキストが空の場合は要約なし
        guard !lines.isEmpty else {
            analysisText = AttributedString("要約する内容がありません。")
            return
        }

        // 見出しと内容を抽出するための辞書と現在処理中の見出し
        var contentByHeading: [String: [String]] = [:]
        var currentHeading = ""

        // 各行を解析し、見出しと内容を辞書に格納
        for line in lines {
            if line.hasPrefix("#") { // 見出し行の場合
                currentHeading = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                contentByHeading[currentHeading] = []
            } else if !currentHeading.isEmpty && !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { // 内容行の場合
                contentByHeading[currentHeading]?.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        // プロジェクト名の抽出
        let projectName = fileName.replacingOccurrences(of: "要件定義書_", with: "")
        // 各要件定義項目の内容を取得
        let purpose = getFirstContent(for: ["目的"], contentByHeading: contentByHeading)
        let people = getFirstContent(for: ["関係者", "体制", "登場人物"], contentByHeading: contentByHeading)
        let functionalRequirements: String = getAllContent(for: ["機能"], contentByHeading: contentByHeading)
        let nonFunctionalRequirements: String = getAllContent(for: ["非機能", "性能要求", "品質要求", "互換性要求", "保守性要求"], contentByHeading: contentByHeading)
        let techSpecs: String = getAllContent(for: ["技術仕様", "動作環境", "必要なソフトウェア", "スクリプトファイル仕様", "コマンド実行順序"], contentByHeading: contentByHeading)
        let constraints: String = getAllContent(for: ["制約", "前提条件", "技術的制約", "コンテンツ制約"], contentByHeading: contentByHeading)
        let deliverables: String = getAllContent(for: ["成果物", "納品物", "生成物"], excluding: ["中間"], contentByHeading: contentByHeading)
        let qa: String = getAllContent(for: ["テスト", "チェックポイント", "エラー処理"], contentByHeading: contentByHeading)
        let scalability: String = getAllContent(for: ["拡張", "展開", "将来的な拡張", "カスタマイズポイント"], contentByHeading: contentByHeading)

        // 人間が読みやすい形式での要約を生成
        let techSpecsSummary = _formatSummarySection(content: techSpecs, sectionName: "開発に必要な技術仕様", prefix: "開発に必要な技術仕様は以下の通りです。")
        let constraintsSummary = _formatSummarySection(content: constraints, sectionName: "制約事項", prefix: "制約事項として以下の内容が挙げられています。")
        let deliverablesSummary = _formatSummarySection(content: deliverables, sectionName: "成果物", prefix: "成果物は以下の通りです。")
        let qaSummary = _formatSummarySection(content: qa, sectionName: "開発後の品質保証", prefix: "開発後の品質保証は、以下の方針で進められます。")
        let scalabilitySummary = _formatSummarySection(content: scalability, sectionName: "将来的な拡張性", prefix: "将来的な拡張性として、以下の点が考慮されています。")

        // システム構成の処理
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

        // 最終的な要約文字列の構築
        var summaryString = ""
        summaryString += "この要件定義は「\(projectName)」プロジェクトに関するもので、\n"
        summaryString += "目的は「\(purpose)」であり、\n"
        summaryString += "関わる人は「\(people)」です。\n\n"
        summaryString += "機能要件は以下の通りです。\n"
        summaryString += functionalRequirements
        summaryString += "\n非機能要件は以下の通りです。\n"
        summaryString += nonFunctionalRequirements
        summaryString += "\n" + techSpecsSummary
        summaryString += "\n" + constraintsSummary
        summaryString += "\n" + systemConfigSummary
        summaryString += "\n" + deliverablesSummary
        summaryString += "\n" + qaSummary
        summaryString += "\n" + scalabilitySummary

        // 生成された要約をanalysisTextに設定
        analysisText = AttributedString(summaryString, attributes: AttributeContainer().foregroundColor(NSColor.white))
        print("analysisText updated. Length: \(NSAttributedString(analysisText).length), Content: \(NSAttributedString(analysisText).string.prefix(100))")
        // 改善提案を生成
        generateSuggestions(contentByHeading: contentByHeading, analysisSummary: summaryString, functionalRequirements: functionalRequirements, nonFunctionalRequirements: nonFunctionalRequirements)
    }

    /// 要約内容と抽出された見出し情報に基づいて改善提案を生成する
    /// - Parameters:
    ///   - contentByHeading: 見出しと内容の辞書
    ///   - analysisSummary: 生成された要約テキスト
    ///   - functionalRequirements: 機能要件の文字列
    ///   - nonFunctionalRequirements: 非機能要件の文字列
    /// 要約内容と抽出された見出し情報に基づいて改善提案を生成する
    /// - Parameters:
    ///   - contentByHeading: 見出しと内容の辞書
    ///   - analysisSummary: 生成された要約テキスト
    ///   - functionalRequirements: 機能要件の文字列
    ///   - nonFunctionalRequirements: 非機能要件の文字列
    private func generateSuggestions(contentByHeading: [String: [String]], analysisSummary: String, functionalRequirements: String, nonFunctionalRequirements: String) {
        var suggestions = Set<String>() // 重複する提案を避けるためにSetを使用

        // 既存の不足セクションの提案
        let commonMissingSections = ["目的", "関係者", "機能", "非機能", "技術仕様", "制約", "システム構成", "成果物", "品質", "拡張"]
        for sectionKey in commonMissingSections {
            if analysisSummary.contains("\(sectionKey)は「記載がありません」") || analysisSummary.contains("\(sectionKey)については、特に記載がありません。") {
                suggestions.insert("・'\(sectionKey)'に関する詳細な情報を追記しましょう。")
            }
        }

        // 内容の具体性に関するアドバイス
        for (heading, contentLines) in contentByHeading {
            let combinedContent = contentLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if combinedContent.count < 30 && !combinedContent.isEmpty { // 30文字未満を「短い」と判断
                suggestions.insert("・'\(heading)' の内容をより具体的に、詳細に記述しましょう。")
            }
        }

        // 特定の要件に関する深掘りアドバイス
        if analysisSummary.contains("機能要件は以下の通りです。") && functionalRequirements.isEmpty {
            suggestions.insert("・主要な機能要件を具体的に記述しましょう。各機能の入出力、処理内容、エラー時の挙動を明確にすると良いでしょう。")
        }
        if analysisSummary.contains("非機能要件は以下の通りです。") && nonFunctionalRequirements.isEmpty {
            suggestions.insert("・性能、品質、セキュリティ、可用性など、非機能要件の具体的な数値目標や基準を明確にしましょう。")
        }

        if let performanceContent = contentByHeading.first(where: { $0.key.contains("性能要求") })?.value.joined(), performanceContent.count < 50 && !performanceContent.isEmpty {
            suggestions.insert("・性能要求には、応答時間、スループット、同時接続数など、具体的な数値目標を記述しましょう。")
        }
        if let securityContent = contentByHeading.first(where: { $0.key.contains("セキュリティ要件") })?.value.joined(), securityContent.count < 50 && !securityContent.isEmpty {
            suggestions.insert("・セキュリティ要件には、認証、認可、データ暗号化、脆弱性対策など、具体的な対策を記述しましょう。")
        }

        // 一般的な要件定義のベストプラクティス
        if !analysisSummary.contains("スコープ") {
            suggestions.insert("・プロジェクトのスコープ（対象範囲と対象外範囲）を明確に定義しましょう。")
        }
        if !analysisSummary.contains("テスト") && !analysisSummary.contains("品質保証") {
            suggestions.insert("・テスト計画や受け入れ基準、品質保証の方針について記述しましょう。")
        }
        if !analysisSummary.contains("運用") && !analysisSummary.contains("保守") {
            suggestions.insert("・システム運用・保守に関する要件（ログ、監視、バックアップ、エラー通知など）を考慮しましょう。")
        }
        if !analysisSummary.contains("ユーザー") && !analysisSummary.contains("関係者") {
            suggestions.insert("・システムを利用するユーザーの種類や役割、権限について明確にしましょう。")
        }
        if !analysisSummary.contains("データ") && !analysisSummary.contains("情報") {
            suggestions.insert("・扱うデータの種類、構造、保存期間、プライバシーに関する考慮事項などを記述しましょう。")
        }

        let suggestionsString: String
        if suggestions.isEmpty {
            suggestionsString = "改善案はありません。"
        } else {
            suggestionsString = suggestions.sorted().joined(separator: "\n") // 一貫した出力のためにソート
        }
        suggestionText = AttributedString(suggestionsString, attributes: AttributeContainer().foregroundColor(NSColor.white))
    }

    /// Markdown形式の要件定義をファイルに保存する
    func saveMarkdownToFile() {
        print("saveMarkdownToFile called")
        // メインスレッドでファイル保存ダイアログを表示
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText] // テキストファイルとして保存
            panel.canCreateDirectories = true // ディレクトリ作成を許可
            panel.nameFieldStringValue = "\(self.fileName).md" // デフォルトのファイル名

            print("NSSavePanel presented for Markdown")
            // 保存ダイアログが表示され、ユーザーがOKを選択した場合
            if panel.runModal() == .OK {
                guard let url = panel.url else {
                    print("Error: Could not get save URL for Markdown.")
                    // エラーアラートを表示
                    self.showErrorAlert(message: "ファイルの保存先URLを取得できませんでした。")
                    return
                }
                do {
                    // Markdownテキストを文字列に変換してファイルに書き込む
                    let markdownString = NSAttributedString(markdownText).string
                    try markdownString.write(to: url, atomically: true, encoding: .utf8)
                    
                    // 保存成功時のパスを保存し、確認アラートを表示
                    self.savedFilePath = url.path
                    self.showSaveConfirmation = true
                    print("Markdown file saved successfully to: \(url.path)")
                    
                } catch { // ファイル書き込みエラー時の処理
                    print("Error saving Markdown file: \(error.localizedDescription)")
                    // エラーアラートを表示
                    self.showErrorAlert(message: "Markdownファイルの保存中にエラーが発生しました: \(error.localizedDescription)")
                }
            } else {
                print("Markdown save panel cancelled by user.")
            }
        }
    }

    /// 要約情報をファイルに保存する
    func saveSummaryToFile() {
        print("saveSummaryToFile called")
        // メインスレッドでファイル保存ダイアログを表示
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText] // テキストファイルとして保存
            panel.canCreateDirectories = true // ディレクトリ作成を許可
            panel.nameFieldStringValue = "\(self.fileName)_要約.txt" // デフォルトのファイル名

            print("NSSavePanel presented for Summary")
            // 保存ダイアログが表示され、ユーザーがOKを選択した場合
            if panel.runModal() == .OK {
                guard let url = panel.url else {
                    print("Error: Could not get save URL for Summary.")
                    // エラーアラートを表示
                    self.showErrorAlert(message: "ファイルの保存先URLを取得できませんでした。")
                    return
                }
                do {
                    // 要約テキストを文字列に変換してファイルに書き込む
                    let summaryString = NSAttributedString(analysisText).string
                    try summaryString.write(to: url, atomically: true, encoding: .utf8)
                    
                    // 保存成功時のパスを保存し、確認アラートを表示
                    self.savedFilePath = url.path
                    self.showSaveConfirmation = true
                    print("Summary file saved successfully to: \(url.path)")
                    
                } catch { // ファイル書き込みエラー時の処理
                    print("Error saving Summary file: \(error.localizedDescription)")
                    // エラーアラートを表示
                    self.showErrorAlert(message: "要約ファイルの保存中にエラーが発生しました: \(error.localizedDescription)")
                }
            } else {
                print("Summary save panel cancelled by user.")
            }
        }
    }

    // エラーアラートを表示するためのヘルパー関数
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "保存エラー"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// プレビュー用のContentView
    static var previews: some View {
        ContentView()
    }
}
