---
title: "Claude Code Skills をチームに配布するベストプラクティス"
date: 2026-02-21
tags: ["claude-code", "skills"]
draft: false
---

個人で育てた Claude Code の Skills（Custom Slash Commands）を、チームで再利用できる形に“配布”し始めると、すぐに次の課題に当たります。

- どこに置けば、みんなが迷わず導入できる？
- 更新をどうやって伝える？ 破壊的変更はどう扱う？
- プロジェクトごとのカスタムと共通の標準をどう共存させる？

この記事では、**Private GitHub リポジトリで Skills を配布する仕組み**を、チームに導入するための実践的なベストプラクティスをまとめます（Claude Code の基本操作は既知前提）。

---

## 1. Skills（Custom Slash Commands）概要おさらい

Claude Code の Skills は、いわゆる **“/コマンドで呼び出せる定型プロンプト（＋手順）”** をチームの資産としてまとめたものです。

- 目的: チーム内の作業の型（レビュー観点、設計テンプレ、調査手順、PR説明生成など）を再現性高く回す
- 形: `/.claude/skills/` 配下に置かれるスキル定義（ファイル）として運用するのが一般的
- 呼び出し: Claude Code から `/skill-name` のように実行できる（詳細操作は割愛）

チーム配布で重要なのは、Skills を「個人のスニペット集」から **“バージョン管理された社内プロダクト”** に昇格させることです。

---

## 2. 推奨: Private GitHub リポジトリを plugin として「社内マーケットプレイス化」する

結論から言うと、チーム配布は次の構成が最も運用しやすいです。

- **共有 Skills を集約した Private リポジトリ（例: `org/claude-code-skills`）を作る**
- 各プロジェクトはその共有リポジトリを何らかの形で取り込む（後述: submodule / subtree / コピーチェックイン）
- 共有リポジトリ側は **README とバージョニング**で「社内プラグイン」として提供する

この形にすると、GitHub 上で以下が自然に実現できます。

- 「どの Skills が公式か」が一目で分かる（README がカタログになる）
- PR レビューで品質担保できる（個人のローカルに閉じない）
- リリース・タグで「今どれを使うべきか」を指示できる
- Issue / Discussions（任意）で改善要求を集約できる

### リポジトリ構成例（共有側）

```text
claude-code-skills/
  README.md
  CHANGELOG.md
  skills/
    pr-review.md
    design-check.md
    incident-triage.md
  templates/           # 任意: 追加ドキュメントや例
  scripts/             # 任意: 配布補助スクリプト
  LICENSE              # 社内用でも明確化推奨
```

> ポイント: 共有リポジトリ直下に `.claude/skills` をそのまま置くのではなく、`skills/` として切り出しておくと、取り込み先で配置を調整しやすくなります（subtree/submodule 時のパス設計が楽）。

---

## 3. 選択肢A: プロジェクトの `.claude/skills` にチェックインする（最も単純）

小規模チームや、プロジェクト固有の Skills が中心なら、**そのプロジェクトのリポジトリに `.claude/skills` を直接コミット**する方法が手堅いです。

### メリット
- 導入が一番簡単（追加コミットだけ）
- 「このリポジトリを clone すればすべて揃う」
- そのプロジェクトの文脈に最適化しやすい

### デメリット
- Skills が複数プロジェクトで重複しがち
- 更新伝搬（直すたびに各リポジトリへ PR）が面倒
- “チーム標準” が育ちづらい

### 向いているケース
- まずは共有より「プロジェクト内標準化」から始めたい
- 共有すべき Skills がまだ少ない／不安定
- 規制やセキュリティ要件で外部参照（submodule 等）を嫌う

---

## 4. 選択肢B: git submodule で共有リポジトリを取り込む

共有 Skills リポジトリを “参照” として取り込む代表が **submodule** です。

### 取り込み例

```bash
git submodule add -b main git@github.com:YOUR-ORG/claude-code-skills.git .claude/skills-shared
git commit -m "Add shared Claude Code skills as submodule"
```

この場合、プロジェクト側では例えば以下の方針にします。

- 共有: `.claude/skills-shared/skills/`（submodule）
- プロジェクト固有: `.claude/skills/`

必要なら README に「共有の Skills はここ」と書き、Claude Code が参照するパスに合わせて運用します（参照方法の細部はチームの運用に合わせて）。

### メリット
- 共有 Skills の更新を “差分として” 取り込める
- 共有リポジトリ側の履歴が保たれる
- 「どのコミットを使っているか」が明確（固定できる）

### デメリット（運用で詰まりやすい）
- submodule の更新手順に慣れていないメンバーがいると事故りやすい
- clone 時に `--recurse-submodules` が必要になりがち
- CI や開発環境側の submodule 初期化漏れが起きやすい

### 運用の最低限ルール（submodule）
- clone 手順を README に明記  
  - `git clone --recurse-submodules ...`
- 既存 clone 向け手順も明記  
  - `git submodule update --init --recursive`
- 更新手順を定型化  
  - `git submodule update --remote --merge`（チーム方針により）

---

## 5. 選択肢C: git subtree で共有リポジトリを取り込む（おすすめ寄り）

submodule が「参照」なら、**subtree は“取り込み（ベンダリング）”**に近い方式です。各プロジェクトの履歴として取り込まれるため、利用者目線では扱いやすくなりがちです。

### 取り込み例（初回）

```bash
git remote add skills git@github.com:YOUR-ORG/claude-code-skills.git
git fetch skills
git subtree add --prefix .claude/skills-shared skills main --squash
```

### 更新取り込み例

```bash
git fetch skills
git subtree pull --prefix .claude/skills-shared skills main --squash
```

### メリット
- submodule より「普通のディレクトリ」に近く扱える
- clone 時の特別対応が不要になりやすい
- 共有側の変更を PR として安全に取り込める

### デメリット
- 取り込み手順を知らないと更新できない（ただし submodule よりは楽）
- 共有側の履歴の扱いはチーム方針次第（`--squash` をどうするか）

### こんなチームに向く
- GitHub 利用は日常的だが submodule は避けたい
- 「各プロジェクトが取り込む時点でレビューしたい」
- “最新版に勝手に追従” より “更新PRを取り込む” を重視

---

## 6. 更新伝搬の工夫（バージョニング、変更通知）

配布で本当に効くのはここです。取り込み方式に関わらず、**更新の設計**がないと一気に形骸化します。

### 6.1 バージョニング方針（最低限これ）
共有 Skills リポジトリに **タグ（例: `v1.2.0`）**を切り、変更の性質を明確にします。

- `MAJOR`: コマンド名変更、入出力の前提変更、手順の破壊的見直し
- `MINOR`: スキル追加、後方互換な改善
- `PATCH`: 誤字修正、軽微な観点追加

submodule を使う場合は「どのタグ/コミットを指すか」で固定しやすく、subtree でも「この更新は v1.3.0 相当」と PR に書けます。

### 6.2 CHANGELOG を必須にする
更新伝搬の要は CHANGELOG です。最低限、以下を毎リリースで書きます。

- Added / Changed / Fixed / Deprecated（形式は任意）
- 影響範囲（例: `/pr-review` の出力が変わる）
- 移行ガイド（破壊的変更がある場合）

### 6.3 変更通知のルートを用意する
通知は「頑張って読む」では続きません。おすすめは以下。

- GitHub Releases を使う（Private でも有効）
- Slack/Teams に GitHub の release 通知を流す（社内運用に合わせる）
- 各プロジェクトに「Skills 更新PR」を定期的に立てる当番を作る（後述）

---

## 7. 運用 Tips（命名規則、README、レビュー体制）

### 7.1 命名規則: “用途＋動詞” で揃える
Skills の命名は、後から効いてきます。おすすめは以下のようなパターン。

- `pr-review`（PR をレビューする）
- `pr-description`（PR 説明文を生成）
- `design-check`（設計観点チェック）
- `incident-triage`（障害一次切り分け）

避けたい例:
- `helpful` / `mytool` のように用途が分からない
- チーム外文脈がないと伝わらない略語

### 7.2 README は “カタログ＋導入方法” にする
共有 Skills リポジトリの README には最低限これを書きます。

- Skills 一覧（1行説明つき）
- 推奨導入方法（subtree か submodule か、または両方）
- 更新方法（コマンド例）
- 互換性方針（破壊的変更の扱い）
- コントリビュート方法（PR テンプレやルール）

README が社内マーケットプレイスの「棚」になります。

### 7.3 レビュー体制: “プロンプト品質” をコードレビューする
Skills は動かすと出力が揺れるため、レビュー観点を明文化すると安定します。

- 目的が一文で説明できるか
- 入力前提（必要な情報）が明記されているか
- 出力フォーマットが一定か（箇条書き、見出し、チェックリスト等）
- セキュリティ/機密の扱い（貼ってはいけない情報の注意書き）
- プロジェクト依存の文言が紛れ込んでいないか（共有の場合）

可能なら CODEOWNERS を設定し、「Skills 変更はこのチームがレビュー」の形にします。

---

## 8. どれを選ぶべきか（おすすめの意思決定）

- **最速で始める**: プロジェクトに `.claude/skills` をチェックイン  
  - まず型を作るフェーズ向き
- **社内マーケットプレイスとして育てる（推奨）**: Private 共有リポジトリ ＋ subtree  
  - 取り込みやすさと更新コントロールのバランスが良い
- **厳密に参照を固定したい**: Private 共有リポジトリ ＋ submodule  
  - 運用ルールを徹底できるチーム向き

個人的なおすすめは、**共有リポジトリを作って、最初は subtree（`--squash`）で取り込む**です。更新は「Skills 更新PR」として各プロジェクトに流せるため、チームの開発フロー（PR/レビュー）に自然に乗ります。

---

## 9. 導入チェックリスト（これだけやれば回り始める）

- [ ] Private の共有 Skills リポジトリを作成（README/CHANGELOG 追加）
- [ ] 命名規則を決め、最低限の “公式 Skills” を 3〜5 個作る
- [ ] 取り込み方式を決める（subtree 推奨 / submodule も可）
- [ ] 各プロジェクトに取り込み、導入手順を README に記載
- [ ] リリースタグ運用（例: 月1で `vX.Y.Z`）を開始
- [ ] 変更通知（GitHub Releases → チャット通知）を設定
- [ ] CODEOWNERS 等でレビュー体制を作る

---

## まとめ

Skills をチームに配布するコツは、「ファイルを共有する」ではなく **“更新できるプロダクトとして配る”** ことです。

- 共有の核は **Private GitHub リポジトリ（社内マーケットプレイス）**
- 取り込みは **subtree（扱いやすい）** か **submodule（参照固定しやすい）**
- 継続の鍵は **バージョニング、CHANGELOG、通知、レビュー体制**

この枠組みを先に作っておくと、Skills は“便利ツール”から“チーム標準”へ育っていきます。