---
title: "Temporal 応用 #5: 本番運用の勘所"
date: 2026-02-24T07:04:00+09:00
series: "temporal-advanced"
author: "ブループリント"
tags: ["temporal", "go", "writer:witty-distributed-systems-engineer"]
draft: false
---

基本編・応用編の前回までで「作り方」はだいぶ手に入ったはずなので、最終回は「育て方」をやりましょう。  
Temporal は“ワークフローという名の長距離列車”を走らせる仕組みなんですよね。開発環境では駅員が目視で何とかなっても、本番になると列車の本数も距離も桁が変わります。なので **メトリクス・監視・運用の型**がないと、駅が一瞬でパンクします。

この記事のゴールは「どこを見て、どうアラートを作り、詰まったらどの順に崩すか」を腹落ちさせることです。

---

## 1. 監視の全体像：Temporal は「3つの箱」を見る

まず、観測ポイントを3つに分けると整理が楽ですよ。

```
[Worker(あなたのアプリ)]  <--gRPC-->  [Temporal Server]  <--->  [DB/ES等]
   |  SDK metrics/logs/traces           | server metrics            | infra metrics
```

- **Worker（SDK側）**: 取りこぼし・詰まり・リトライ嵐が最初に出る場所  
- **Temporal Server**: タスクキューの滞留、スケジューリング遅延、内部エラー  
- **周辺基盤**: DB 遅延・枯渇、ネットワーク、ノード不調

この記事は「Worker（SDK）と運用手順」を中心に書きます（自前ホスティングの深掘りはしません）。

---

## 2. SDK メトリクスと Prometheus 連携（Go）

Temporal の運用で一番効くのは「Worker をメトリクスでしゃべらせる」ことです。  
Worker は、駅員が見ている **改札の通過人数**・**ホームの混雑**・**遅延**を全部知ってる存在なので、ここを黙らせないのが大事です。

### 2.1 Prometheus エクスポート（最小構成）

Go SDK では `tally` を使ってメトリクススコープを渡します（Temporal SDK が内部でメトリクスを発火します）。

```go
import (
  "github.com/prometheus/client_golang/prometheus/promhttp"
  "net/http"

  "github.com/uber-go/tally/v4"
  "github.com/uber-go/tally/v4/prometheus"
  "go.temporal.io/sdk/client"
  "go.temporal.io/sdk/worker"
)

func main() {
  reporter := prometheus.NewReporter(prometheus.Options{
    Registry: promhttp.Handler().(prometheus.Gatherer), // 例示：実際は専用Registry推奨
  }, prometheus.DefaultSanitizer)

  scope, _ := tally.NewRootScope(tally.ScopeOptions{
    Prefix:   "temporal_worker",
    Reporter: reporter,
  }, 1)

  c, _ := client.Dial(client.Options{
    HostPort: "temporal:7233",
    MetricsHandler: scope, // ここが肝
  })

  w := worker.New(c, "payment-task-queue", worker.Options{
    MetricsHandler: scope,
  })

  go func() {
    http.Handle("/metrics", promhttp.Handler())
    _ = http.ListenAndServe(":2112", nil)
  }()

  _ = w.Run(worker.InterruptCh())
}
```

> 実運用では Prometheus の `Registry` を明示し、アプリのメトリクスと混ざり方を設計するのが吉です（名前衝突・ラベル設計の事故が減ります）。

### 2.2 何のメトリクスを見るべき？

SDK/Worker 側でまず見たいのは、ざっくりこの4カテゴリです。

- **タスク処理のスループット**（処理できているか）
- **レイテンシ**（処理に時間がかかってないか）
- **失敗率/リトライ率**（燃えてないか）
- **ポーリング関連**（タスクキューから取れているか）

Temporal のメトリクス名はバージョンで揺れることもあるので、最初は「メトリクス名を暗記」よりも、**ダッシュボードで“形”を掴む**のが効きます。  
具体的には：

- Worker が生きてるのに **ポーリングが減る** → 取りに行けてない（ネットワーク、権限、スロット枯渇）
- **処理数が横ばい**なのに **タスクキュー滞留**が増える → 供給過多か Worker 容量不足
- **失敗率が増える** → Activity の依存先が死んでる、Non-Determinism、タイムアウト設定ミス

---

## 3. アラート設計のポイント：「症状」と「原因」を分ける

アラートは「鳴らすこと」より「鳴った後に動けること」が大事ですよね。  
Temporal では特に、**症状アラート**と**原因アラート**を分けると運用が安定します。

### 3.1 症状アラート（ユーザー影響に近い）

- Workflow 完了までの遅延が急増
- Task Queue の backlog が増え続ける（一定時間で戻らない）
- Workflow/Activity の failure が増加

これは「列車が遅れてます」系。オンコールがまず見るやつです。

### 3.2 原因アラート（調査をショートカットする）

- Worker のポーリングエラー増加（gRPC エラー、認証、名前解決）
- Worker の concurrency 枯渇（処理スロット不足）
- 依存先（DB、外部API）のエラー・タイムアウト増加

これは「信号機が赤のまま」「線路が詰まってる」系。原因に近いので復旧が早くなります。

---

## 4. Namespace 設計と管理：運用の“防火区画”を作る

Namespace は「同じ建物の中の別フロア」みたいなもので、運用上の境界線になります。  
Temporal ではこの境界の引き方が、監視・権限・変更の安全性に直結します。

### 4.1 どう分けるか（現場でよく効く切り方）

- **環境で分ける**: `dev` / `stg` / `prod`  
  → 監視とアラートを綺麗に分離できます
- **組織/ドメインで分ける**: `payments` / `fulfillment`  
  → 権限と責任範囲が揃います
- **大規模なら「環境×ドメイン」**: `prod-payments` など  
  → “同じ本番”でも爆発範囲を絞れます

> Task Queue 名で頑張るより、Namespace で防火区画を作る方が、運用の事故が減りやすいです。

### 4.2 ライフサイクル管理のコツ

- **保持期間（retention）**を用途に合わせる  
  監査・調査が必要なドメインは長め、そうでないなら短め  
- Namespace 単位で **アラートの閾値**を変える  
  “バッチ系”と“同期系”を同じ遅延SLOで縛ると誤検知が増えがちです

---

## 5. よくあるトラブルと対処法（手順つき）

ここが一番欲しいところですよね。  
Temporal のトラブル対応は「ログを眺める」より、**状態を特定してから手を打つ**のが早いです。

### 5.1 スタックした Workflow（進まない / 終わらない）

「止まってる」にはだいたい3種類あります。

```
(1) Activity待ち   (2) Timer待ち   (3) Signal待ち
```

#### まず見る（Web UI）
- Workflow の **Event History** で最後のイベントを確認
- `ActivityTaskScheduled` の後に `ActivityTaskStarted/Completed` があるか
- Timer/Signal の待ち状態になっていないか

#### よくある原因と打ち手
- **Activity が開始されない**  
  - Task Queue 名違い、Worker がそのキューを poll してない
  - Worker が落ちてる / 過負荷で concurrency 枯渇  
  → Worker 数を増やす、concurrency 設定を見直す、Task Queue を分割
- **Activity がリトライ地獄**  
  - 依存先が落ちている・レート制限  
  → Retry Policy をドメインに合わせる（最大試行回数・バックオフ・non-retryable を整理）
- **Signal 待ちが永遠**  
  - 呼び出し側が signal を送ってない / 送る相手を間違えてる  
  → 送信側の監視（Signal 成功率）を作る、Correlation ID を徹底

> たとえると「料理が出ない」問題で、(1)厨房が止まってる、(2)オーブンのタイマー待ち、(3)注文が通ってない、のどれかをまず切り分ける感じです。

---

### 5.2 Non-Determinism エラー（再現しにくい、でも致命傷）

Non-Determinism は「過去のイベント履歴を再生したら、別の分岐に行ってしまった」状態です。  
Temporal はワークフローを **イベントソーシング的にリプレイ**するので、ここがズレると破綻します。

#### 典型原因
- Workflow 内で `time.Now()` や乱数、外部API呼び出しなど、**非決定的な値**を直接使う
- コード変更で `if/else` の条件や `Selector` の分岐が変わった
- ループの回数が履歴と一致しなくなった

#### まずやること
- Web UI で該当 Workflow の failure を開いて、**どのイベントで崩れたか**を確認
- 直近のデプロイ差分を見て、Workflow 定義の変更点を洗い出す

#### 対処の基本方針
- **Workflow のバージョニング**（`GetVersion` など）で履歴互換を維持する  
- 非決定的なものは **Activity 側**に逃がす（Workflow は“台本”、Activity は“現場”と割り切る）

---

### 5.3 リトライ嵐で負荷が雪だるま式に増える

Temporal は賢くリトライしてくれる反面、設定次第で「全員が一斉にリトライ」という事故が起きます。  
例えるなら、出口が詰まってるのに「全員いったん外に出て並び直してね」を繰り返す感じです。

見るべき観点：
- 失敗の種類が **永続的エラー**（バリデーション、権限）なのか **一時的エラー**（タイムアウト）なのか
- backoff が短すぎないか（スパイクを作っていないか）

打ち手：
- Non-retryable を明確化（エラー型、原因コード）
- backoff と最大試行回数をドメイン要件に合わせる
- 外部APIに対してはレート制限/サーキットブレーカも併用（Temporal だけで守り切らない）

---

## 6. Temporal Web UI / tctl の活用：現場で役立つ“3点セット”

Web UI は「今なにが起きてるか」を見るのに強く、tctl は「一括・自動化」に強いです。  
両方使えると運用の解像度が上がります。

### 6.1 Web UI で見るべきポイント
- Workflow の **Status / History / Pending Activities**
- Retry の回数、最後の failure、次の retry 時刻
- Task Queue の滞留状況（環境によって見え方は変わります）

「まず Web UI で個体を診察 → まとめて対処は tctl」みたいに使うと迷いが減ります。

### 6.2 tctl でよく使う操作（例）

> コマンドはバージョンで差があるので、手元の `tctl --help` を正にしましょう。ここでは“運用での使い所”を優先して例を載せます。

- Workflow の一覧・詳細確認  
- 特定条件での検索（Workflow ID / Run ID / 時刻 / ステータス）
- 問題のある Workflow の terminate/cancel（影響を理解した上で慎重に）

運用で効くのは「検索条件をチームでテンプレ化」することです。  
「障害時に誰が打っても同じ情報に辿り着ける」状態が作れます。

---

## 7. 仕上げ：本番運用チェックリスト（最小）

最後に、運用の“型”として持っておくと効くものを置いておきます。

- [ ] SDK メトリクスを Prometheus に出している（Worker 側）
- [ ] 症状アラート（遅延/滞留/失敗）と原因アラート（poll/依存先/枯渇）を分離
- [ ] Namespace を環境・責務境界として設計し、retention と権限を揃えている
- [ ] スタック時の一次切り分け手順（Activity/Timer/Signal）をチームで共有
- [ ] Non-Determinism の回避策（決定性・バージョニング）を開発ルール化
- [ ] Web UI と tctl の「よく使う操作」をテンプレ化（オンコールの迷子防止）

---

## おわりに

Temporal は「正しく作れば壊れにくい」一方で、「観測できないと直しにくい」タイプの道具なんですよね。  
なので本番では、ワークフローの設計と同じ熱量で **メトリクス・アラート・調査導線**を設計しておくのが効きます。

シリーズはここで一区切りです。次にやるなら、あなたのサービスの1つのドメインを選んで「SLO → 監視 → 失敗の分類 → リトライ設計」を1周回してみるのが一番伸びます。技術というより“運用の筋トレ”ですね。