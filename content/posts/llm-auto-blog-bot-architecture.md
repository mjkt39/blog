---
title: "LLM 自動記事生成 bot を作った話"
date: 2026-02-26T14:00:00+09:00
tags: ["go", "temporal", "clean-architecture", "llm"]
draft: false
summary: "Go+Temporal+Clean Architectureで、LLMの記事生成を運用に耐える形に落とし込む設計パターンを整理する。"
description: "LLM自動記事生成を「スクリプト1枚」から脱却。Go+Temporal+Clean Architectureでパイプライン、依存設計、DIまで実装視点で解説。"
---

## はじめに：LLMにブログを「丸投げ」すると起きる現実

LLM API を叩いて Markdown を出すだけなら、確かにスクリプト1枚で動きます。ところが、運用を考えた瞬間に論点が変わります。たとえば次のような「現場っぽい」要求が出てきます。

- 生成が遅い／失敗するので、リトライ・再開がほしい  
- 途中成果（アウトライン、下書き、校正結果）を保存して追跡したい  
- 同じ入力で違う出力が出るので、バージョニングと再現性を確保したい  
- 品質チェック（文字数、禁止表現、リンク、frontmatter）を機械的に通したい  
- 生成が暴走したときに止めたい（コスト・レート制限）  

ここで「LLM=賢い関数」扱いをやめ、**非決定的で失敗しやすい外部システム**として設計し直す必要が出ます。この記事では、僕が自動記事生成 bot を作ったときに採用した **Go + Temporal + Clean Architecture** の構成を、設計パターンとして取り出して説明します。プロンプトやTemporalの個別機能の深掘りはしません。狙いは「自分の自動化プロジェクトに転用できる骨格」を持ち帰ってもらうことです。

---

## 全体アーキテクチャ：Go + Temporal + Clean Architecture を選んだ理由

### 何を作ったか（ざっくり）
入力（投稿計画）から、以下を段階的に生成します。

1. メタ情報（title/summary/description/tags）整形  
2. 記事構成案（見出し）  
3. 本文ドラフト  
4. 検査（文字数、禁止ワード、frontmatter、体裁）  
5. 修正ループ（必要なら）  
6. 最終成果を保存して通知

ここで重要なのは、**「生成」より「工程管理」**です。LLMは工程の一部で、全体はワークフローになります。

### Go：実務で効く点
- バイナリ配布しやすく、運用が軽い  
- 並行処理・I/Oが素直で、外部API連携が書きやすい  
- 型があるので「生成物の構造」をモデル化しやすい（後述の依存設計に効く）

評価：LLM周りは速度より保守性が支配的で、Goの「読みやすさ・壊しにくさ」が効きます。一方で、DSL的に書きたい層（プロンプト生成など）は冗長になりがちで、そこはテンプレートやビルダーで吸収するのが現実的です。

### Temporal：なぜキューでもCronでもなくワークフローか
LLM自動化は、だいたい「長い・失敗する・途中から再開したい」です。ジョブキュー（Redis/Cloud Tasks/SQS）でも組めますが、実装が「状態管理の自作」になりがちです。

Temporal を選んだ理由は次です。

- ステップが多い処理を **ワークフロー** として表現できる  
- 失敗時のリトライやタイムアウトを、分散ジョブとして筋よく扱える  
- 途中経過を保持しつつ **再開** が現実的（人間の介入も入れやすい）

評価：Temporalは学習コストと設計コストが乗ります。ただ、LLMパイプラインは早晩「バッチ処理」ではなく「業務プロセス」になっていくので、そこでの投資対効果は高いと感じました。

比較：
- **単発バッチ + DB**：最初は速いが、再開・リトライ・観測性で負債化  
- **ジョブキュー**：分割はできるが、状態遷移が散らばる  
- **Temporal**：中心にワークフローを置ける。設計が前提になる

### Clean Architecture：LLMを「差し替え可能」にする
LLM API は変わります。モデルも変わります。品質チェックのルールも変わります。だから、LLM連携をアプリ中心から隔離しないと、改修が全体に波及します。

Clean Architecture で得たメリットは、

- 生成手順（ユースケース）と、LLM/DB/通知の実装を分離できる  
- テストが「LLMなし」で成立し、品質を守りやすい  
- Temporal を「実行基盤」として外に追いやれる（後述の依存方向）

評価：抽象が増えて初速は落ちます。ただ、LLM自動化はプロダクト化しやすい領域で、後から運用要件が雪だるま式に増えます。初期から境界を引く価値は大きいです。

---

## レイヤー構成と依存方向：どこにTemporalを置くか

Clean Architecture の要点は「依存方向」です。内側（ドメイン・ユースケース）が外側（フレームワーク・I/O）を知らないようにします。

### レイヤー例（このbotの分割）
- **domain**：記事生成の概念  
  - `ArticlePlan`, `ArticleDraft`, `Frontmatter`, `ValidationResult` など  
- **usecase**：工程（パイプライン）の意思決定  
  - 例：`GenerateArticle`, `ReviseDraft`, `ValidateArticle`  
- **interface adapters**：外部との変換  
  - LLM応答→ドメインモデル、ドメイン→Markdown整形、リポジトリI/O  
- **infrastructure**：Temporal/LLM SDK/DB/Slack など実装  
- **cmd**：DI組み立て、起動

依存は次の向きに限定します。

- infrastructure → adapters → usecase → domain  
- （逆向き参照をしない）

### Temporalはどこに置くか
Temporalを「usecaseの中で直接呼ぶ」設計も見かけますが、僕は避けました。理由は、Temporalの都合（リトライ設定、Activity境界、シリアライズ制約）がユースケースに侵食しやすいからです。

方針：
- **usecaseは純粋なアプリの手順**を表現  
- Temporal は **その手順を実行するランナー**（infrastructure）  
- ワークフローが呼ぶのは usecase ではなく、「Activity = 外部I/Oを伴う操作」に寄せる

ここは意見が分かれるところです。評価としては、Temporalに寄せすぎるとワークフローがアプリそのものになり、将来「別の実行基盤」に移りにくい。一方で、Temporalに寄せると運用はしやすい。今回は「アプリの核を長持ちさせる」方向に倒しました。

---

## 記事生成パイプライン：ワークフロー設計の勘所

### ステップを「成果物」で区切る
LLMパイプラインは、関数分割よりも **成果物（アーティファクト）** で区切ると事故が減ります。

- `Outline`（見出し構造）  
- `Draft`（本文）  
- `ReviewedDraft`（チェック結果つき）  
- `FinalArticle`（frontmatter + 本文）

こうしておくと、途中保存・差し戻し・再実行の単位が明確になります。実務的には「失敗したのでアウトラインからやり直す」「レビューだけ再実行する」が発生します。

### Temporalワークフローは「状態機械」になる
イメージは以下です。

- 入力：投稿計画（plan）  
- 状態：`outlineReady`, `draftReady`, `validated`, `revisionsCount` など  
- 分岐：検査NGなら修正ループ、コスト上限なら停止、など

擬似コード（雰囲気）：

```go
// workflow層（infrastructure）: 状態遷移の制御
func ArticleWorkflow(ctx workflow.Context, plan domain.ArticlePlan) error {
    outline := workflow.ExecuteActivity(ctx, ActGenerateOutline, plan).Get(...)
    draft := workflow.ExecuteActivity(ctx, ActGenerateDraft, plan, outline).Get(...)

    for i := 0; i < 3; i++ {
        report := workflow.ExecuteActivity(ctx, ActValidate, plan, draft).Get(...)
        if report.OK {
            break
        }
        draft = workflow.ExecuteActivity(ctx, ActReviseDraft, plan, draft, report).Get(...)
    }

    workflow.ExecuteActivity(ctx, ActPublish, plan, draft).Get(...)
    return nil
}
```

ここでのポイントは、**LLMを呼ぶ処理はActivity側**に寄せ、ワークフロー側は「分岐と回数制御」に集中させることです。LLM応答の揺れがあるため、「何回で止めるか」「止めた場合に何を残すか」はコスト管理として効きます。

### 実務への影響：品質ゲートを工程に組み込める
人間のレビューに頼っていると、生成物が増えるほど破綻します。ワークフローに検査ステップを入れると、

- 禁止ワード、文字数、frontmatter欠落、見出し構造などを機械で担保  
- NGのときの「修正依頼」をLLMに返すループが作れる  
- 生成ログと成果物が紐づき、監査しやすい

展望：今後は、生成だけでなく「社内規約・法務・ブランドトーン」などのチェックが先に肥大化します。LLM活用の勝ち筋は、生成モデルの差よりも **工程として品質を閉じる設計**に寄っていくはずです。

---

## DIの組み立て：各層のつなぎ方（Go 1.22+）

Clean Architecture を採ると、DI（依存注入）をどう組むかが実装の山場になります。結論から言うと、Goでは過剰なDIフレームワークを入れず、**手組みで十分**です。重要なのは「生成物のインターフェース境界」を揃えること。

### 代表的なインターフェース
usecase層が欲しい依存を定義します。

```go
// usecase ports
type LLMClient interface {
    Generate(ctx context.Context, req PromptRequest) (PromptResponse, error)
}

type ArticleRepository interface {
    SaveDraft(ctx context.Context, d domain.ArticleDraft) error
}

type Notifier interface {
    Notify(ctx context.Context, msg string) error
}
```

infrastructureはそれを実装します（OpenAI/Claude互換、DB、Slackなど）。TemporalのActivityは「usecaseを呼ぶ薄い層」か、「infrastructureの実装を直接使う層」になりますが、ここはチームの好みが出ます。

僕の評価としては、**Activityはアダプタ寄り**にして、ドメイン変換や入出力整形を閉じ込めるのが扱いやすいです。Temporalの引数・戻り値はシリアライズ都合があるので、そこにドメインの複雑さを漏らさない方が運用が楽になります。

### cmdでの手組みDI例
`cmd/worker/main.go` で組み立てます。

- infra（LLM SDK/DB/通知）を生成  
- adapters（変換・整形）を生成  
- usecaseに注入  
- Temporal workerにActivity/Workflowを登録

この形にすると、テストでは `LLMClient` をモックに差し替えて、`ValidateArticle` などのユースケースを単体で回せます。実務的にはここが効きます。LLM API を叩くE2Eテストだけだと、速度・コスト・非決定性でテストが腐りやすいからです。

---

## 他アプローチとの比較：どこまで「プロダクション品質」を狙うか

- **ローカルスクリプト**：学習用途には良いが、工程が伸びた瞬間に破綻しやすい  
- **ワンショット生成 + 人手修正**：最初は回るが、スループットが頭打ちになる  
- **ワークフロー + 品質ゲート**：設計コストはあるが、運用要件（再開、監査、コスト制御）に耐える

僕の意見は、LLM自動化は「生成精度」より「運用設計」が差になる局面に入っています。モデルが賢くなるほど、やりたい自動化は大きくなり、失敗時のハンドリングや品質保証が主要課題として残ります。Temporalのようなワークフロー基盤と、Clean Architectureの境界設計は、その課題に対する堅い回答です。

---

## まとめ：スクリプトから設計へ、最初に押さえるべき骨格

- LLM呼び出しは本体ではなく、**工程の一部**として扱う  
- Go + Clean Architecture で、**差し替え可能な境界**を作る  
- Temporal で、長い処理を **状態遷移として管理**し、再開・観測・コスト制御を入れる  
- DIは手組みでよく、重要なのは **依存方向** と **成果物単位の分割**

この骨格があると、「記事生成」以外にも、議事録生成、問い合わせ返信案、コードレビュー補助、社内ドキュメント整備など、LLM自動化の多くを同じ型で組み立てられます。スクリプト1枚を卒業して、運用に耐える自動化に進むときの足場として参考になれば嬉しいです。