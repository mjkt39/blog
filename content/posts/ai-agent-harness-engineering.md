---
title: "AI エージェントのハーネスエンジニアリング — コードで品質を縛る技術"
date: 2026-03-28T09:44:15+09:00
tags: ["ai", "agent", "harness-engineering", "quality"]
draft: false
summary: "プロンプト外のハーネスで、エージェント品質を機械的に安定化する。"
description: "AIエージェントの出力ばらつきを、ルール・スキーマ・テスト・CIで拘束し再現性を上げる設計思想を解説。"
---

## イントロ：プロンプトだけで品質を担保しようとして破綻する

AI エージェント開発を日常的に回していると、次の悩みが常態化します。

- 同じ入力でも「微妙に違う」出力が出て、差分レビューが地獄になる  
- 実行のたびにツール呼び出しの順序・回数が揺れ、コストや副作用が安定しない  
- 「正しさ」の定義がプロンプトや人間の解釈に寄りすぎ、システムとしての境界条件が曖昧になる  

ここで効くのが **ハーネスエンジニアリング**です。要点はシンプルで、**プロンプトで説得するのではなく、コードで縛る**。  
モデルの自由度を前提にしつつ、**自由に動ける範囲を狭める外骨格**を用意して、出力の再現性と運用耐性を上げます。

近年この方向性が強くなった背景には、エージェントが「文章生成」から「ツール実行・業務オペレーション」に寄ってきたことがあります。MCP（Model Context Protocol）のような標準化が進み、ツール連携が急拡大するほど、**誤実行・逸脱・セキュリティ事故**が現実のコストとして降ってきます。 ([modelcontextprotocol.io](https://modelcontextprotocol.io/specification/2025-06-18/server/tools?utm_source=openai))

---

## ハーネスとは何か：エージェントを「安全に動かす枠」

本記事でいうハーネスは、次の総称です。

- **入力・出力・ツール実行**の各フェーズに、機械的な制約と検証を挿入する仕組み
- 「良い感じ」を目指すのではなく、**逸脱を検出して止める／矯正する**仕組み
- 運用上は、**観測（tracing）と評価（eval）**もハーネスの一部になる

この考え方は、OpenAI の Agents SDK が **Guardrails（入力・出力・ツールの検証）と Tracing（実行の観測）**を強調している点にも表れています。 ([openai.com](https://openai.com/index/new-tools-for-building-agents//?utm_source=openai))

筆者の評価：  
プロンプト中心の時代は「言葉で振る舞いを誘導」でしたが、エージェント時代は「実行系」なので、**ソフトウェア工学の手触り（制約・テスト・境界・パイプライン）に回帰している**のが健全です。一方で、ハーネスが弱いままツール面だけ広げると、事故は時間の問題です（MCP 周辺のセキュリティニュースがそれを示唆します）。 ([itpro.com](https://www.itpro.com/security/a-malicious-mcp-server-is-silently-stealing-user-emails?utm_source=openai))

---

## 1) エージェント組み込みハーネス機能の概観（rules files / hooks / skills）

### 何がトレンドか
最近のエージェント基盤は、だいたい次を標準装備し始めています。

- **ルールの外部化**：ルールやポリシーを「コード／設定」として分離し、モデルの会話から切り離す  
- **フック（hooks）/ パイプライン**：実行の前後（入力→計画→ツール→出力）に割り込めるポイント  
- **スキル（skills）/ ツール定義**：モデルが呼べる能力を宣言的に列挙し、許可されない行為を閉じる  

OpenAI Agents SDK の Guardrails は、ツール呼び出し周辺のパイプラインとして説明されており、どこに適用されないか（例：handoff や一部 hosted tools）まで明記されています。ここが「ハーネス」の設計論に直結します。 ([openai.github.io](https://openai.github.io/openai-agents-python/guardrails/?utm_source=openai))  
また、Semantic Kernel でもプランニング（どの関数をどう呼ぶか）が概念として整理され、移行ガイドまで用意されています。 ([learn.microsoft.com](https://learn.microsoft.com/en-us/semantic-kernel/concepts/planning?utm_source=openai))

### 実務への影響
- ルールが会話文に埋まっていると、変更がレビュー不能になりがちです。外部化すると **差分が読める**。
- フックがあると、逸脱時の振る舞い（中断・再試行・縮退・人間承認）を**プロンプトでなく制御フローで書ける**。
- スキル定義があると、エージェントの能力が棚卸しされ、**権限設計（least privilege）**に接続できます。

### 筆者の意見
ポジティブ：  
「プロンプトの中で言い聞かせる」のをやめ、**実行系としての境界**を引けるのは、品質とセキュリティの両面で大きい。

ネガティブ：  
フック／スキルが増えるほど、エージェントの挙動は「結局どのルールが勝つのか」という**優先順位問題**に突入します。ハーネス自体の設計が散らかると、本末転倒です。

### 今後の展望
標準化はさらに進み、MCP のように「ツールの露出が容易」になるほど、**ルール・権限・観測の標準化**も同時に求められます。MCP は仕様改訂が継続しており、運用側の要求で育っていることが読み取れます。 ([modelcontextprotocol.info](https://modelcontextprotocol.info/blog/first-mcp-anniversary/?utm_source=openai))

---

## 2) Linter / Formatter / 静的解析による「出力矯正」

### なぜ効くのか
エージェント出力の品質ぶれは、内容の正しさ以前に「形式のぶれ」として顕在化します。

- JSON が壊れる  
- フィールド名が揺れる  
- 余計な説明文が混ざる  
- コード生成なら lint に通らない  

ここで「モデルに頑張ってもらう」のではなく、**出力を機械的に整形・拒否・再生成**する方が、運用上の期待値が揃います。

### 実務への影響
- 人間レビューが「文章の揺れ」ではなく **差分の本質（仕様差）**に集中できる  
- 後段システム（DB 更新・決済・デプロイ等）に入る前の故障が減り、**運用コストが落ちる**
- モデル更新時の影響が「lint failure」として表面化しやすく、**回帰検知**に効く

### 筆者の意見
ポジティブ：  
Linter/Formatter/静的解析は、AI以前から鍛えられてきた「現場の武器」です。エージェントにもそのまま適用でき、投資対効果が高い。

ネガティブ：  
矯正が強いと「形式は通るが意味は破綻」が残ります。形式チェックは入口で、後述の TDD/SDD/DDD に繋げないと片手落ちです。

### 比較：プロンプト矯正との違い
- プロンプト：モデルの気分に左右される、説明は増えるが保証は増えにくい  
- ハーネス：失敗を検知して止める、再試行戦略を持てる、CI で再現可能  

---

## 3) TDD によるテストファースト仕様駆動（エージェント版）

### 何が変わるのか
エージェントの「正しさ」は、自然言語の納得感より **テストに落ちるか**で定義した方が強いです。  
TDD は古典ですが、エージェント時代に再評価される理由は、**出力の揺れを前提に“受け入れ条件”を先に固定できる**からです。

OpenAI もエージェントの評価（Agent evals / Evals）をガイドとして整備し、「一貫性・正確性」を評価で担保する方向を示しています。 ([platform.openai.com](https://platform.openai.com/docs/guides/agent-evals?utm_source=openai))

### 実務への影響
- 「この挙動で良いのか」を会話で詰めるのではなく、**失敗するテストとして提示**できる  
- モデルやプロンプトを変えたときの回帰が、CI で機械的に出る  
- エージェントの暴走（ツール誤呼び出し、無限ループ、過剰コスト）を **非機能テスト**として管理しやすい

### 筆者の意見
ポジティブ：  
エージェントの議論を「感想戦」から「検証可能な仕様」に引き戻せます。これはチーム開発の摩擦を減らします。

ネガティブ：  
テストが弱いと「通ったから良い」が発生します。特に生成物の品質（要約、提案、文章）は、合否の設計が難しい。ここで **SDD（スキーマ制約）やドメイン境界**が補助線になります。

---

## 4) SDD（Spec-Driven Development）によるスキーマ制約

### トレンド：Structured Outputs の普及
近年の大きな流れとして、LLM の出力を **スキーマ準拠**に寄せる機能が普及しています。Anthropic は「schema-related parsing errors を減らす」狙いを明確にした Structured Outputs を紹介し、ツール定義への準拠（strict tool use）もドキュメント化しています。 ([claude.com](https://www.claude.com/blog/structured-outputs-on-the-claude-developer-platform?utm_source=openai))

### 実務への影響
- JSON 修復や例外処理が減り、エージェントの後段が安定する  
- ツール呼び出しが「それっぽい文章」から「構造化データ」になることで、**事故の型**が減る  
- スキーマが仕様の中心になると、プロンプトは「補助線」へ降格し、保守性が上がる

### 筆者の意見
ポジティブ：  
SDD はエージェントの品質ブレに対して、最も即効性があるアプローチの一つです。スキーマはレビュー可能で、差分も追いやすい。

ネガティブ：  
スキーマを厳密にしすぎると、探索的なタスク（調査・仮説・提案）で表現力が落ち、ワークフローが硬直します。  
設計としては「最終成果物」や「ツール入出力」を硬くし、途中の思考は柔らかく、が現実的です。

### 今後の展望
構造化出力と観測（trace）が揃うと、次は「そのスキーマが満たすべき意味論」をどう検証するかに移ります。つまり **型（schema）から契約（contracts / invariants）**へ、という流れです。

---

## 5) DDD + Clean Architecture：ドメイン境界でアーキテクチャを強制する

### なぜ今これか
エージェントは「何でもできる顔」をします。だからこそ、システム側で次を徹底しないと破綻します。

- どの層が何を知ってよいか（依存方向）  
- どこで外界（API/DB）に触れてよいか  
- どの判断がドメインで、どれがアプリケーション都合か  

DDD + Clean Architecture は、エージェントを中心に据えたときにも強いです。理由は、**モデルは境界を理解しない前提で、境界をコードが守る**から。

### 実務への影響
- エージェントが UI/インフラ層を直叩きする構造を避けられる  
- 事故が起きたとき、責務が分離されているほど原因究明が速い  
- 「エージェントを差し替える」「モデルを変える」が、ドメインを壊さずに済む

### 筆者の意見
ポジティブ：  
生成 AI 導入で最も失われがちなのは「境界」です。DDD/Clean は古典ですが、エージェント時代の保険として価値が上がっています。

ネガティブ：  
チームが境界設計に不慣れだと、抽象化が儀式になり、速度が落ちます。ハーネスは宗教ではなく、**事故コストと釣り合う範囲**でやるべきです。

### 比較：ガードレール機能との関係
- Guardrails/スキーマ：局所的（入出力・ツール呼び出し）  
- DDD/Clean：大域的（システム設計の制約、依存関係）  

局所と大域の両方が噛み合うと、初めて「壊れにくいエージェント」になります。

---

## 6) CI を最終防衛線としたパイプライン品質ゲート

### なぜ CI が「最後」なのか
ハーネスは実行時にも効きますが、組織開発では CI が「強制力のある契約」になりやすい。  
特にエージェントは変更頻度が高い（プロンプト、モデル、ツール、スキーマ、ルールが同時に動く）ため、**人間の注意力では追いつきません**。

OpenAI の Agents SDK が tracing/evals を押し出しているのは、CI と接続しやすい形で「観測と評価」を提供する意図が読み取れます。 ([openai.com](https://openai.com/index/new-tools-for-building-agents//?utm_source=openai))  
Microsoft Foundry 側でも tracing を OpenTelemetry 規約に寄せる動きがあり、運用観測がパイプライン化していく流れが見えます。 ([devblogs.microsoft.com](https://devblogs.microsoft.com/foundry/whats-new-in-microsoft-foundry-dec-2025-jan-2026?utm_source=openai))

### 実務への影響
- PR ごとに「最低限の品質」を機械的に通す文化が作れる  
- 本番での事故が、テスト・lint・スキーマ・セキュリティチェックで手前に寄る  
- モデル更新やプロバイダ変更時も、**同じゲート**で比較できる

### 筆者の意見
ポジティブ：  
CI を品質ゲートにすると、チームが「どこまでを品質として扱うか」を合意しやすい。

ネガティブ：  
CI が重くなると開発が詰まります。ここは段階設計が重要で、たとえば  
- 軽い静的検査は常時  
- 重いエージェント評価は nightly  
のような割り切りが要ります。

---

## まとめ：ハーネスは「自由度の管理」であり、エージェント開発の本丸

エージェントの品質課題は、モデルの賢さより **自由度の大きさ**から来ます。  
だから解法は、プロンプトの技巧を積むことより、プロンプトの外側にある **制約（schema）・検証（lint/test/eval）・境界（architecture）・ゲート（CI）**を整備することに寄ります。

- rules / hooks / skills：実行系の制御点を作る  
- Linter / Formatter / 静的解析：形式の揺れを機械的に潰す  
- TDD：正しさをテストとして固定する  
- SDD：構造を契約として固定する  
- DDD + Clean：システム境界で逸脱を起こしにくくする  
- CI：組織としての強制力を持つ最終ゲートにする  

今後、MCP の普及でツールが増えるほど、ハーネスの価値は上がります。一方で、MCP 周辺ではセキュリティ事故・脆弱性の話題も増えており、**「繋げる」より先に「縛る」**が重要になっています。 ([itpro.com](https://www.itpro.com/security/a-malicious-mcp-server-is-silently-stealing-user-emails?utm_source=openai))

---

## 参考リンク（引用元）
※リンクは参照用（本記事は how-to や設定例を目的にしていません）

- OpenAI: New tools for building agents（Agents SDK / tracing / guardrails）  
  `https://openai.com/index/new-tools-for-building-agents//` ([openai.com](https://openai.com/index/new-tools-for-building-agents//?utm_source=openai))
- OpenAI Agents SDK Docs: Guardrails  
  `https://openai.github.io/openai-agents-python/guardrails/` ([openai.github.io](https://openai.github.io/openai-agents-python/guardrails/?utm_source=openai))
- OpenAI Platform Docs: Agent evals  
  `https://platform.openai.com/docs/guides/agent-evals` ([platform.openai.com](https://platform.openai.com/docs/guides/agent-evals?utm_source=openai))
- Anthropic: Structured outputs on the Claude Developer Platform  
  `https://www.claude.com/blog/structured-outputs-on-the-claude-developer-platform` ([claude.com](https://www.claude.com/blog/structured-outputs-on-the-claude-developer-platform?utm_source=openai))
- Anthropic Docs: Structured outputs / strict tool use  
  `https://docs.claude.com/en/docs/build-with-claude/structured-outputs` ([docs.claude.com](https://docs.claude.com/en/docs/build-with-claude/structured-outputs?utm_source=openai))
- Model Context Protocol Spec: Tools（2025-06-18）  
  `https://modelcontextprotocol.io/specification/2025-06-18/server/tools` ([modelcontextprotocol.io](https://modelcontextprotocol.io/specification/2025-06-18/server/tools?utm_source=openai))
- Model Context Protocol Spec: Servers overview（2025-11-25）  
  `https://modelcontextprotocol.io/specification/2025-11-25/server/index` ([modelcontextprotocol.io](https://modelcontextprotocol.io/specification/2025-11-25/server/index?utm_source=openai))
- Microsoft Learn: Semantic Kernel Planners（更新: 2025-06-11）  
  `https://learn.microsoft.com/en-us/semantic-kernel/concepts/planning` ([learn.microsoft.com](https://learn.microsoft.com/en-us/semantic-kernel/concepts/planning?utm_source=openai))
- Microsoft Foundry Blog: What’s new（Dec 2025 & Jan 2026 / tracing overhaul）  
  `https://devblogs.microsoft.com/foundry/whats-new-in-microsoft-foundry-dec-2025-jan-2026/` ([devblogs.microsoft.com](https://devblogs.microsoft.com/foundry/whats-new-in-microsoft-foundry-dec-2025-jan-2026?utm_source=openai))
- ITPro: malicious MCP server がメールを盗む事例（2025-09-26）  
  `https://www.itpro.com/security/a-malicious-mcp-server-is-silently-stealing-user-emails` ([itpro.com](https://www.itpro.com/security/a-malicious-mcp-server-is-silently-stealing-user-emails?utm_source=openai))
- TechRadar: Anthropic の Git MCP server の脆弱性（CVE-2025-68145）  
  `https://www.techradar.com/pro/security/anthropics-official-git-mcp-server-had-some-worrying-security-flaws-this-is-what-happened-next` ([techradar.com](https://www.techradar.com/pro/security/anthropics-official-git-mcp-server-had-some-worrying-security-flaws-this-is-what-happened-next?utm_source=openai))