---
title: "AI エージェント開発 Weekly（2026/03/23–03/29）"
date: 2026-03-29T07:49:00+09:00
series: "ai-agent-dev-weekly"
tags: ["ai", "agent", "weekly", "development-practice"]
draft: false
summary: "権限自動化とJetBrainsのエージェント強化、データ学習方針変更が焦点。"
description: "Claude Codeの権限自動化、CursorのエージェントUI、CopilotのJetBrains強化と学習データ方針変更を実務目線で解説。"
---

## 今週の概観（2026/03/23–03/29）
今週は「**エージェントに何を任せるか**」が一段進みました。具体的には、(1) Claude Code が“権限確認”のボトルネックを減らす方向へ、(2) Cursor が“エージェントの対話UI/拡張配布”を整備、(3) Copilot が JetBrains 側で“カスタムエージェント/サブエージェント/Plan”を一般提供、そして (4) Copilot の**インタラクションデータ学習ポリシー変更**が開発現場の運用（設定/ガバナンス/ログ設計）に直撃、という流れです。 ([techradar.com](https://www.techradar.com/pro/anthropic-gives-claude-code-new-auto-mode-which-lets-it-choose-its-own-permissions?utm_source=openai))

---

## 開発プラクティス・Tips

### 1) 「権限プロンプト地獄」を設計で潰す：Claude Code “auto mode”の捉え方
Anthropic が Claude Code に **auto mode（研究プレビュー）**を投入。従来は長いタスクで「操作のたびに許可確認」が止まりやすかったのに対し、auto mode はアクションを分類し、危険度が低いものは自動実行、リスクがありそうなものだけユーザーに確認を返す方向です。Teams 向け提供・Sonnet 4.6 / Opus 4.6 対応が言及されています。 ([techradar.com](https://www.techradar.com/pro/anthropic-gives-claude-code-new-auto-mode-which-lets-it-choose-its-own-permissions?utm_source=openai))

- **実務への影響（どう関係するか）**
  - “許可を押す係”が発生していたチームほど効きます。特にリファクタや大量ファイル編集のような**長距離タスクの停止回数**が減り、ペアプロの体験が改善します。
  - 一方で、権限が自動化されるほど「いつ何が実行されたか」を追える形（ログ/差分/チェックポイント）を先に整備しないと、レビュー側が不安になります。

- **筆者の評価・意見**
  - **ポジティブ**：エージェント活用の生産性を落としていた“人間のクリック待ち”を正面から解消しにきたのは良い判断です。
  - **ネガティブ**：研究プレビューである以上、誤判定（安全なのに止まる／危険なのに通る）前提で運用設計が要ります。速度のために安全が揺れると、結局は現場で無効化されます。

- **背景分析 / 今後の展望**
  - 「完全自律」か「常時許可」かの二択だと現場導入が進みにくい。そこで**“許可の自動化レイヤ”**を製品側が持つのは自然な流れです。今後は auto mode の判断基準が、チームポリシー（例：削除/外部通信/秘密情報周り）に寄っていくはずです。

- **他アプローチとの比較**
  - ルールベースな allowlist/denylist だけだと例外が多すぎるため、分類器を挟む設計は現実的。ただし、最終的に必要なのは「分類器の説明可能性」よりも**変更差分に対する検証導線（テスト/CI/レビュー）**です。

- **明日からの使い方（実務コメント）**
  - auto mode を入れるなら、まずは**“危険操作の定義”をチームで文章化**（例：削除、権限変更、秘密情報の参照、外部送信）。
  - その上で、エージェントの作業単位を「PR 1本でレビューできる粒度」に縛る（大作業をさせても、レビュー不能だと結局止まります）。

---

### 2) “Plan → 実装 → 検証”を分業する：JetBrainsでのCopilotカスタム/サブエージェント一般提供
GitHub Copilot for JetBrains IDEs で **Custom agents / sub-agents / plan agent が一般提供**になりました。JetBrains を主戦場にしているチームでも、役割分担型のエージェント運用が組みやすくなります。 ([github.blog](https://github.blog/changelog/2026-03-11-major-agentic-capabilities-improvements-in-github-copilot-for-jetbrains-ides/?utm_source=openai))

- **実務への影響**
  - 「実装役」「テスト役」「ドキュメント役」など、**職能別にプロンプト規約・禁止事項・出力形式**を分けられます。レビュー観点も揃えやすい。
  - JetBrains で完結するため、VS Code 前提のワークフロー（指示ファイルの置き場や、エージェント起動手順）を移植しやすくなります。

- **筆者の評価・意見**
  - **ポジティブ**：サブエージェントは「プロンプトを長文化して全部盛り」より事故が減ります。責務分離はエージェントでも効く。
  - **注意点**：サブエージェントが増えると、トークン/回数/待ち時間の“見えないコスト”が増えます。速さのためにサブエージェントを増やしすぎると逆効果になりやすい。

- **背景 / 展望**
  - ここ1年の流れは、単発チャットから**“組織の作業標準をエージェントに埋め込む”**方向。JetBrains 側の一般提供は「大規模導入」を狙った整備に見えます。

- **他アプローチとの比較**
  - Cursor や Claude Code は“エージェント中心”で IDE を横断しやすい一方、Copilot は GitHub 連携（PR/Issue/Repo）まで含めた統合が強み。JetBrains 強化は「IDEの主戦場がJetBrainsの企業」に刺さります。

- **明日からの使い方**
  - まず2種類だけ作るのが現実的です：  
    1) **Plan用エージェント**（変更方針、影響範囲、テスト計画だけ出す）  
    2) **実装用エージェント**（Planに従って差分を作る）  
  - “実装エージェントが勝手に仕様を変える”事故が減ります。

---

### 3) エージェントの対話を「UI部品」に寄せる：Cursorの“interactive UIs in agent chats”
Cursor の更新で、**エージェントチャット内のインタラクティブUI**や、**チームで共有できるプライベートプラグイン**などが入り、Debug mode も改善されたとされています。 ([cursor.com](https://cursor.com/changelog/?utm_source=openai))

- **実務への影響**
  - エージェントに「選択肢を提示→人が選ぶ→次の一手へ」の導線を作りやすい。  
    例：リファクタ方針（小分けPR/一括）や対象モジュールの選択を UI 化して、合意形成の摩擦を下げる。
  - プライベートプラグイン共有は、社内の“作法”（例：命名、レイヤ構造、ログ規約、チケット運用）をツールとして配布する動きと相性が良いです。

- **筆者の評価・意見**
  - **ポジティブ**：エージェント活用が進むほど「テキストだけの合意形成」が限界に当たります。UI 化は現場導入を進める手段として有効です。
  - **懸念**：UI が増えると、プロンプトの可搬性（別IDE/別エージェントへの移植）が落ちます。標準化したいチームは“UI依存度”を意識した設計が必要。

- **背景 / 展望**
  - エージェントが強くなるほど、入力は自然言語だけでは足りず、**“半構造化の入力”**（フォーム/選択/テンプレ）が必要になります。Cursor はそこを製品機能として取り込みにいっている印象です。

- **明日からの使い方**
  - チームで1つだけ“UI化する儀式”を決めると効果が出ます（例：PR作成前の変更方針確認、テスト範囲選択）。最初から全部をUI化しない方が運用が安定します。

---

## 主要ツール・サービスのリリース/アップデート

### 4) Copilotの「学習データ」方針変更：2026-04-24開始のインパクト整理
報道ベースでは、**2026-04-24 以降**、GitHub Copilot のインタラクションデータ（入力/出力/コード断片/関連コンテキスト等）が学習に使われる方針が示され、オプトアウトが前提になる旨が伝えられています。 ([windowscentral.com](https://www.windowscentral.com/software-apps/microsofts-github-is-going-to-start-using-copilot-interactions-to-train-ai-models-and-its-starting-soon?utm_source=openai))

- **実務への影響**
  - これは“開発体験”というより**運用とガバナンス**の話です。個人開発や小規模チームほど設定を見落としやすく、後から問題化しがちです。
  - 「何をCopilotに渡すか（貼り付けるか）」のルールが曖昧な組織は、プロンプトに秘密が混ざる事故が起きます。学習有無に関係なく、入力設計が必要です。

- **筆者の評価・意見**
  - **ニュートラル寄り（ただし要対応）**：プロダクト改善に実利用データを使うのは自然ですが、現場は“自然”では回りません。設定確認、社内ポリシー、教育がセットです。
  - 開発者体験としては、ここを曖昧にすると「安心できないから使わない」に直結します。結果として、導入の伸びを自分で削るリスクもあります。

- **背景 / 展望**
  - コーディングエージェントは、一般会話よりも「環境・依存・リポジトリ構造・慣習」に性能が左右されます。実利用の相互作用データを欲しがるのは合理的です。
  - 今後は、個人/OSS/企業でデータ扱いが分岐し、**“組織向けはより強いデータ分離と監査”**が競争軸になると見ています。

- **他アプローチとの比較**
  - Claude Code / Cursor など他のツールでも、最終的には「どのデータがどの目的で保持・利用されるか」を把握する必要があります。Copilot は GitHub の統合が強い分、運用設計も一緒に求められます。

- **明日からの使い方（実務コメント）**
  - 週明けにやることを3つに絞ると現実的です。  
    1) **各メンバーの設定確認**（学習に関する項目、組織アカウントとの関係）  
    2) **“貼って良い情報/悪い情報”の線引き**（鍵、トークン、顧客情報、内部URLなど）  
    3) **プロンプトテンプレ**を配布（「目的」「制約」「期待する差分」「テスト」を定型化し、余計な情報を入れにくくする）

---

## 今週のまとめ：持ち帰りチェックリスト
- **Claude Code**：auto mode は“許可確認の停止”を減らす。導入前に危険操作と差分レビューの導線を固める。 ([techradar.com](https://www.techradar.com/pro/anthropic-gives-claude-code-new-auto-mode-which-lets-it-choose-its-own-permissions?utm_source=openai))  
- **Copilot（JetBrains）**：Custom/sub-agents + Plan agent の一般提供で、役割分担ワークフローをIDE内に持ち込める。 ([github.blog](https://github.blog/changelog/2026-03-11-major-agentic-capabilities-improvements-in-github-copilot-for-jetbrains-ides/?utm_source=openai))  
- **Cursor**：対話をUI部品化し、チーム配布（プライベートプラグイン）へ。儀式を1つだけUI化から始める。 ([cursor.com](https://cursor.com/changelog/?utm_source=openai))  
- **Copilotポリシー**：2026-04-24開始の学習データ方針は、設定・教育・テンプレ配布が先。 ([windowscentral.com](https://www.windowscentral.com/software-apps/microsofts-github-is-going-to-start-using-copilot-interactions-to-train-ai-models-and-its-starting-soon?utm_source=openai))  

来週は「Plan→実装→検証」を、ツール機能ではなく**チームの標準手順**として固定化できるかが差になりそうです。