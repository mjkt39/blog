---
title: "今週のマルチエージェント動向 - 使えそうなやつだけピックアップしてみた"
date: 2026-02-24T23:56:00+09:00
author: "よもやまテック"
tags: ["ai", "multi-agent", "orchestration", "news", "writer:easygoing-it-commentator"]
draft: false
---

今週も「エージェント」という単語が、そこらじゅうで増殖してるんだよね。  
で、情報量が多すぎて脳のメモリがスワップし始めるわけだ。誰がこのワークロードを許可した。

ということで今回は **2026-02-17〜2026-02-24** の範囲に絞って、「マルチエージェント」「オーケストレーション（段取り・実行制御）」「プロトコル（エージェント同士/ツールとの通信規約）」に関係する動きだけを、仕事目線で拾っていく。  
単一エージェントの精神論とか、モデルのベンチ勝負とかは置いていく（置いていかれた側の気持ちは考えない）。

---

## 今週の結論（忙しい人向け）
- **MCP** は「周辺（SDK/運用/ガバナンス）」が整ってきて、実務投入の現実味が上がってる。特に *SDKの成熟度が可視化* されたのがデカい。 ([modelcontextprotocol.io](https://modelcontextprotocol.io/community/sdk-tiers))  
- **A2A** は「エージェント間の標準会話」を狙う路線がはっきりしてきた。MCPと競合というより、役割が違う（後で触れる）。 ([agent2agent.info](https://agent2agent.info/))  
- **オーケストレーション運用** は「つくる」より「安全に回す」フェーズの話が増えた。LangSmith（旧LangGraph Platform周辺）の更新が、地味に効いてくる。 ([docs.langchain.com](https://docs.langchain.com/langsmith/self-hosted-changelog))  

---

## 1) MCP（Model Context Protocol）: “道具箱につなぐ標準” が運用フェーズへ

### 1-1. MCP SDK Tiering（SDK格付け）が公開（2026-02-23）
MCP公式が **SDK Tiering System** を公開。SDKを Tier 1〜… みたいに分類して、プロトコル対応やメンテ方針の期待値を揃えに来たんだよね。  
重要なのはここで、**「どのSDKを採用するか」を意思決定しやすくなった** って点。選定会議で“雰囲気”を減らせる。 ([modelcontextprotocol.io](https://modelcontextprotocol.io/community/sdk-tiers))

**仕事でどう使う？**  
- MCP採用を検討してるチームは、まずこのTierを見て「今の運用要件（保守/対応範囲/品質）に合うSDK」を選ぶと良い。  
- 逆に、社内標準SDKを決めたい場合も「Tierで足切り」できる。これ、地味だけど購買/情シス/セキュリティレビューが速くなるやつ。

**出典（一次）**: MCP公式 Community “SDK Tiering System” ([modelcontextprotocol.io](https://modelcontextprotocol.io/community/sdk-tiers))

---

### 1-2. MuleSoft MCP Server がツール拡張（2026-02-06だけど今週触る価値あり）
「今週（2/17〜2/24）」の縛りからは外れるんだけど、実務的に刺さる更新なので紹介。MuleSoftのMCP Serverで、API実装やMUnitテスト生成系ツールが更新されてる。  
要は「統合基盤（iPaaS）に、エージェント経由で手を入れやすくする」方向。 ([docs.mulesoft.com](https://docs.mulesoft.com/release-notes/mulesoft-mcp-server/mulesoft-mcp-server-release-notes))

**仕事でどう使う？**  
- “仕様→実装→テスト” の流れがMCPツール化されてくると、**社内の統合開発をエージェントで半自動化**しやすい。  
- 監査観点でも「ツール呼び出しログ」が残せる設計に寄せれば、野良スクリプトより安全に寄せられる。

**出典（一次）**: MuleSoft MCP Server Release Notes ([docs.mulesoft.com](https://docs.mulesoft.com/release-notes/mulesoft-mcp-server/mulesoft-mcp-server-release-notes))

---

### 1-3. Okta MCP Server が本番GA（2026-02-04だけど、MCPの現実解として強い）
こちらも週次範囲から少し前。ただし「MCPが机上の空論じゃなく、ID基盤に刺さり始めた」事例として価値がある。Oktaが **Okta MCP Server GA** を明記してる。 ([developer.okta.com](https://developer.okta.com/docs/release-notes/2026-okta-mcp-server/))

**仕事でどう使う？**  
- エージェントが業務で暴れないためには、結局 **権限設計（least privilege）** がすべてなんだよね。  
- OktaみたいなID/権限の中心にMCPがいると、「ツール実行の認可」をプロダクションに載せやすい。  
- “エージェントに管理APIを渡すの怖い問題” を、多少は現実路線に引き戻してくれる。

**出典（一次）**: Okta MCP Server API release notes ([developer.okta.com](https://developer.okta.com/docs/release-notes/2026-okta-mcp-server/))

---

## 2) A2A（Agent2Agent）: “エージェント同士の会話” を標準化したい勢

### 2-1. A2A Protocol Community: Agent Card / Task管理 / セキュリティを前面に
A2Aのコミュニティサイトを見ると、主語がでかい。  
でもやろうとしてることは割と実務寄りで、**Agent Card（能力カード）で発見**して、**Taskで仕事を依頼**して、**ストリームや非同期**も扱って…という「業務の部品」を揃えに来てる。 ([agent2agent.info](https://agent2agent.info/))

**仕事でどう使う？**  
- 社内に複数のエージェント（例: 調査係、実装係、レビュー係、デプロイ係）が出てきたとき、今はだいたい“独自JSON”で会話しがち。  
- A2A的な枠があると、**発見→依頼→進捗→成果物** の流れを共通化しやすい。  
- MCPが「ツールにつなぐ」なら、A2Aは「エージェント同士をつなぐ」寄り。混ぜると強い。

**出典（一次）**: Agent2Agent Protocol Community ([agent2agent.info](https://agent2agent.info/))

---

## 3) マルチエージェントフレームワーク: “作る”から“回す”へ寄ってきた話

### 3-1. CrewAI: A2A寄りの実装が進んでる（直近は 2026-01-26 v1.9.0）
週次範囲内（2/17〜2/24）に新リリースは見当たらなかったけど、直近のv1.9.0で **A2A task execution utilities** や **A2A server config / agent card generation** が入ってるのは、今週の文脈（A2A盛り上がり）とつながって面白い。 ([docs.crewai.com](https://docs.crewai.com/en/changelog))

**仕事でどう使う？**  
- CrewAIを採用してるなら、A2A周辺の機能は「将来、社内の別フレームワーク/別チームのエージェントと繋ぐ」布石になる。  
- “マルチエージェントを作ったはいいが、閉じた世界で終わる問題” を回避しやすい。  
- あと **structured outputs**（構造化出力）が横断で効く。マルチエージェントは結局「受け渡しの形式」が崩れると爆発するので。 ([docs.crewai.com](https://docs.crewai.com/en/changelog))

**出典（一次）**: CrewAI Changelog ([docs.crewai.com](https://docs.crewai.com/en/changelog))

---

### 3-2. LangSmith（オーケストレーション運用面）: MCP Server作成時の注意喚起など（2026-02-12 / 2026-02-14）
“フレームワークの新機能” って派手だけど、現場で効くのはこういう「ミスりやすいところを塞ぐ」変更なんだよね。  
Self-hosted LangSmith の更新で **MCP server作成時の重複URL警告** とか、UI/セキュリティ改善が入ってる。 ([docs.langchain.com](https://docs.langchain.com/langsmith/self-hosted-changelog))

**仕事でどう使う？**  
- MCPサーバを複数立てて運用し始めると、「設定ミス」こそが最大の敵になる。重複URLみたいな凡ミスで事故る。  
- LangSmith側でガードレールが増えるほど、**マルチエージェント実運用の“摩擦”が減る**。  
- あと self-hosted の5xxで内部情報が漏れない系の修正は、監査・セキュリティレビューで刺さる。 ([docs.langchain.com](https://docs.langchain.com/langsmith/self-hosted-changelog))

**出典（一次）**: Self-hosted LangSmith changelog ([docs.langchain.com](https://docs.langchain.com/langsmith/self-hosted-changelog))

---

## 4) 「今週、何を触る？」チェックリスト（行動に落とすやつ）
情報を読んで満足すると、エージェントは1ミリも動かない。悲しいね。

### A. MCPを業務に入れる最短ルート
1. MCP SDK Tiering を見て、採用SDKの候補を決める ([modelcontextprotocol.io](https://modelcontextprotocol.io/community/sdk-tiers))  
2. 既存SaaS（OktaやMuleSoftみたいな）で **“公式MCPサーバ”** がある領域から始める ([developer.okta.com](https://developer.okta.com/docs/release-notes/2026-okta-mcp-server/))  
3. ログと権限を最初から設計する（「あとでやる」が一番コスト高）

### B. A2Aは「社内エージェント連携の設計図」として読む
- いきなり全社標準プロトコルにする必要はない。  
- まずは A2Aの概念（Agent Card / Task / streaming）を、**社内のエージェントI/F設計**に借りる。 ([agent2agent.info](https://agent2agent.info/))  

### C. CrewAI採用組は “受け渡しフォーマット” を先に固める
- structured outputs（構造化出力）と、A2A連携の芽を押さえる ([docs.crewai.com](https://docs.crewai.com/en/changelog))  

---

## おまけ: 今週の一言
マルチエージェント界隈、去年まで「とりあえず動いた」自慢が多かったんだけど、今は「どう安全に回すか」「どう他と繋ぐか」に寄ってきた感があるんだよね。  
つまり、やっと仕事の世界に降りてきた。やっとだよ。遅刻してきた主役みたいな顔しやがって。

来週もまた、使えそうなやつだけ拾ってくる。読み切れないニュースは置いていく（そして誰も困らない）。