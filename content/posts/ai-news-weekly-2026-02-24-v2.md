---
title: "今週の AI ニュース - すぐ仕事に使えるやつだけピックアップしてみた"
date: 2026-02-24T18:18:00+09:00
author: "よもやまテック"
tags: ["ai", "news", "tools", "writer:easygoing-it-commentator"]
draft: false
---

今週もAI界隈、更新が多すぎて「追うのが仕事」みたいになってるんだよね。いや、誰がそんな職を望んだ。  
というわけで今回は **2026/02/17〜02/24 の1週間**に出た話の中から、**“今日の業務で触れるやつ”**だけを3〜5本に絞って持ってきた。ベンチ比較は置いとく。規制も置いとく。研究発表も今回は見ない。手を動かしてナンボだろう。

---

## 1) ChatGPT：Interactive Code Blocks（コードブロックが「その場で動く」寄りに進化）
**何が起きた？**  
ChatGPTのコードブロックが、ただの貼り付け表示じゃなくて **編集・プレビュー・分割ビューでのレビュー**など、対話しながら手元でいじれる方向に強化された。地味に「貼った→直した→また貼った」の往復が減るやつ。 ([help.openai.com](https://help.openai.com/en/articles/6825453-chatgpt-release-notes?utm_source=openai))

**仕事でどう使う？（現場目線）**
- **サンプルコードの微調整**：API呼び出し例を貼って「ここだけ例外処理足して」みたいな雑な要求を、その場で整形していける
- **図やミニアプリのプレビュー**：Markdownの図（例：Mermaid）や簡単なUI断片を、レビューしながら潰せる
- **レビュー補助**：分割ビューで差分を見つつ「この関数名、命名規約に寄せて」みたいな地味タスクが進む

**出典（一次情報）**  
- OpenAI Help Center「ChatGPT — Release Notes（2026/02/19）」 ([help.openai.com](https://help.openai.com/en/articles/6825453-chatgpt-release-notes?utm_source=openai))

---

## 2) ChatGPT：Thinking 手動選択時のコンテキスト拡大（256k tokens）
**何が起きた？**  
Thinkingを手動で選ぶとき、ChatGPTのコンテキストが **合計256k tokens（入力128k＋出力最大128k）**になった。前は196kだったので、長文・大量ログ・設計資料を「途中で忘れる問題」が少しマシになる方向。 ([help.openai.com](https://help.openai.com/en/articles/6825453-chatgpt-release-notes?utm_source=openai))

**仕事でどう使う？**
- **長い仕様書＋既存コードの突合**：要件、API定義、既存実装の抜粋をまとめて入れて「矛盾点だけ列挙して」みたいなチェックに向く
- **障害対応のタイムライン整理**：ログ、インシデントメモ、PR履歴を突っ込んで「起点っぽいところ」探しをさせる
- **設計レビューの下準備**：ADR（Architecture Decision Record）候補を複数並べて、比較表を作らせる

**出典（一次情報）**  
- OpenAI Help Center「ChatGPT — Release Notes（2026/02/20）」 ([help.openai.com](https://help.openai.com/en/articles/6825453-chatgpt-release-notes?utm_source=openai))

---

## 3) Zendesk：Voice AI Agents（電話対応をAIエージェントで自動化、EAP）
**何が起きた？**  
Zendeskのリリースノート（〜2026/02/20）で、**Zendesk Voice向けのAI Agents（EAP）**が触れられてる。電話の受付〜意図把握〜手続き（生成手順やAPIアクション）〜必要なら人間へエスカレーション、までを“会話の文脈を保持しつつ”やる系。コールセンターがある組織には刺さるやつ。 ([support.zendesk.com](https://support.zendesk.com/hc/en-us/articles/10343445378202-Release-notes-through-2026-02-20?utm_source=openai))

**仕事でどう使う？**
- **一次受付の自動化**：よくある問い合わせ（パスワード再発行、契約プラン確認、障害の切り分け）をAIに寄せて、人間は難しいやつへ
- **API連携で処理まで**：本人確認→チケット作成→ステータス変更→フォロー連絡、みたいな“手順仕事”を固めやすい
- **品質管理がしやすい**：会話ログが残るので、改善サイクルを回しやすい（ここ重要、誰が何を言ったで揉めにくい）

**出典（一次情報）**  
- Zendesk「Release notes through 2026-02-20」 ([support.zendesk.com](https://support.zendesk.com/hc/en-us/articles/10343445378202-Release-notes-through-2026-02-20?utm_source=openai))

---

## 4) ChatGPT Atlas：Saved Prompts（よく使うプロンプトをブックマーク化）
**何が起きた？**  
ChatGPT Atlasのリリースノートで、**Saved Prompts**が追加。チャット内のプロンプトをブックマークして、`@`などで呼び出して使い回せる。つまり「毎回同じ儀式（前提説明）を唱える」作業が減る。儀式は宗教だけで十分だろう。 ([help.openai.com](https://help.openai.com/en/articles/12591856-release-notes?utm_source=openai))

**仕事でどう使う？**
- **定型レビュー依頼**：「このPRを“影響範囲・互換性・監視観点”でチェックして」みたいな型を固定
- **ログ解析テンプレ**：「このログから、(1)原因候補 (2)追加で欲しい情報 (3)暫定回避策 を出す」みたいな手順を保存
- **文章系の整形**：障害報告、週報、リリースノート作成の“語調”を揃えるテンプレにする

**出典（一次情報）**  
- OpenAI Help Center「ChatGPT Atlas - Release Notes（2026/02/04）」 ([help.openai.com](https://help.openai.com/en/articles/12591856-release-notes?utm_source=openai))  
※Atlas自体の更新日は2/4だけど、今週時点で参照しやすい一次情報としてここにまとまってる。

---

## 5) 今週の「触る順番」おすすめ（迷ったらこれ）
情報が多いと手が止まるんだよね。なので順番を置いとく。

1. **ChatGPTのInteractive Code Blocks**を触る（小さく効く） ([help.openai.com](https://help.openai.com/en/articles/6825453-chatgpt-release-notes?utm_source=openai))  
2. 長文を扱う人は、**Thinking + 256k**で「資料を丸ごと入れる」系を試す ([help.openai.com](https://help.openai.com/en/articles/6825453-chatgpt-release-notes?utm_source=openai))  
3. CS/サポート体制があるなら、Zendeskの**Voice AI Agents（EAP）**を検討（刺さればデカい） ([support.zendesk.com](https://support.zendesk.com/hc/en-us/articles/10343445378202-Release-notes-through-2026-02-20?utm_source=openai))  
4. 仕事の型が固まってる人ほど、**Saved Prompts**で儀式を自動化 ([help.openai.com](https://help.openai.com/en/articles/12591856-release-notes?utm_source=openai))  

---

## おわりに：AIは「新機能」じゃなくて「雑務の引き取り先」
今週のやつ、派手なモデルの話じゃなくて、わりと真面目に **“作業の流れ”を変える更新**が多いんだよね。  
コードブロックが扱いやすくなる、長文を飲み込める、定型プロンプトを保存できる、電話対応を自動化できる。つまり「人間の手を戻す」アップデートってわけだ。

来週もどうせ何か増える。増えるんだけど、まずは今週のうちに1個だけ触って、体に馴染ませていこうぜ。