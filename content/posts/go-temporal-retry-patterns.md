---
title: "Go の Temporal ワークフローで学ぶリトライパターン入門"
date: 2026-02-19
tags: ["Go", "Temporal", "retry", "workflow", "backend"]
draft: false
---

Temporal を使うと「失敗した処理をどう再実行するか」をワークフローの設計として明確に扱えます。本記事では、Go の Temporal SDK を前提に、リトライポリシー（RetryPolicy）の基本と、実務で迷いがちな設定の考え方を、アクティビティ／ワークフロー両方の視点から整理します。

> 前提：Temporal のインストールやセットアップは扱いません。Go + Temporal SDK をすでに触れる読者を想定します。

---

## 1. Temporal のリトライポリシー概要

Temporal のリトライは、主に次の2つのレイヤで登場します。

- **Activity の自動リトライ**
  - Temporal が失敗を検知すると、**同じアクティビティを同じ入力で再実行**します。
  - 外部 API 呼び出しや DB 操作など「失敗しうる I/O」をアクティビティに閉じ込める設計と相性が良いです。
- **Workflow 内でのリトライ（アクティビティ呼び出しの制御、子ワークフロー等）**
  - ワークフロー自体を「最初からやり直す」のではなく、通常は**ワークフローがアクティビティや子ワークフローに適用するリトライ方針**を調整します。
  - 「このエラーはリトライしたい／したくない」「最大何回までにする」などの意思決定をワークフロー側で表現します。

Temporal の重要なポイントは、**リトライが“スケジューラ任せの再実行”ではなく、履歴に記録され再現性のある挙動になる**ことです。したがって、ワークフロー側は *決定的 (deterministic)* に、アクティビティ側は *副作用を持つ* 前提で設計します。

---

## 2. RetryPolicy の各パラメータを理解する

Go SDK では `temporal.RetryPolicy`（SDK のバージョンによりパッケージは `go.temporal.io/sdk/temporal` など）を使います。代表的なパラメータは以下です。

### 2.1 InitialInterval（初回の待機時間）

- **最初のリトライまでの待機時間**です。
- 例：`1s` にすると、失敗後 1 秒待ってから 2 回目を試します。

「瞬断」「一時的な 5xx」など短時間で復帰しうる障害では短めが有効ですが、外部 API を過剰に叩かないように注意します。

### 2.2 BackoffCoefficient（指数バックオフ係数）

- リトライ間隔を増やすための係数です（指数バックオフ）。
- 次の待機時間は概ね `次 = 前 * BackoffCoefficient` で増えます。
- 例：`InitialInterval=1s, BackoffCoefficient=2.0` なら `1s → 2s → 4s → 8s ...`

外部依存が落ちている時に、呼び出し頻度を自然に下げられます。

### 2.3 MaximumAttempts（最大試行回数）

- **最初の試行を含めた**最大回数です。
- `1` なら「リトライなし（1回だけ試す）」という意味になります。
- 「無限リトライ」にしたい場合は、SDK/サーバの仕様によって表現が異なるため注意してください（`0` を無限扱いにする実装が多い一方、利用環境やポリシーで制限されることもあります）。チームの運用方針として明示的な上限を設けるのが無難です。

### 2.4 MaximumInterval（待機時間の上限）

- バックオフで増え続ける待機時間に **上限** を設けます。
- 例：`MaximumInterval=30s` なら、`... 32s` のように増えそうでも `30s` に丸められます。

外部 API の復旧が読めない場合、待機が際限なく長くなりすぎないよう抑制できます。

---

## 3. アクティビティのリトライ設定（基本形）

Temporal では、アクティビティ実行時に `workflow.ActivityOptions` を設定し、その中で `RetryPolicy` を指定するのが基本です。

```go
import (
	"time"

	"go.temporal.io/sdk/temporal"
	"go.temporal.io/sdk/workflow"
)

func MyWorkflow(ctx workflow.Context) error {
	ao := workflow.ActivityOptions{
		StartToCloseTimeout: 30 * time.Second,
		RetryPolicy: &temporal.RetryPolicy{
			InitialInterval:    1 * time.Second,
			BackoffCoefficient: 2.0,
			MaximumInterval:    30 * time.Second,
			MaximumAttempts:    5,
		},
	}
	ctx = workflow.WithActivityOptions(ctx, ao)

	// workflow.ExecuteActivity(...)

	return nil
}
```

ポイント：

- `StartToCloseTimeout` などタイムアウト系は **リトライとセットで考える**必要があります。  
  例：1 回の試行が長時間ブロックしてしまうと、リトライ回数を確保しても全体が遅延します。
- リトライが有効な場合、アクティビティがエラーを返すたびにポリシーに従って再実行され、最終的に成功するか、最大試行回数に達するとワークフロー側にエラーが返ります。

---

## 4. ワークフロー側のリトライ設定とは何か

Temporal では「ワークフロー関数自体を勝手に再起動してリトライ」するというより、以下の形で **ワークフローが呼び出す単位** に対してリトライを適用することが多いです。

- **アクティビティに RetryPolicy を付ける**（最も一般的）
- **子ワークフロー（Child Workflow）の実行に RetryPolicy を付ける**
- （補足）ワークフロー開始時のオプションとしてのリトライも存在しますが、運用設計の影響が大きく、まずは「外部 I/O はアクティビティでリトライ」を軸に理解すると混乱が少ないです。

### 4.1 子ワークフローのリトライ（必要なときだけ）

機能単位でワークフローを分割している場合、子ワークフローが失敗した時に「子をリトライする」という戦略が取れます。

```go
import (
	"time"

	"go.temporal.io/sdk/temporal"
	"go.temporal.io/sdk/workflow"
)

func ParentWorkflow(ctx workflow.Context) error {
	cwo := workflow.ChildWorkflowOptions{
		WorkflowExecutionTimeout: 10 * time.Minute,
		RetryPolicy: &temporal.RetryPolicy{
			InitialInterval:    2 * time.Second,
			BackoffCoefficient: 2.0,
			MaximumInterval:    1 * time.Minute,
			MaximumAttempts:    3,
		},
	}
	ctx = workflow.WithChildOptions(ctx, cwo)

	f := workflow.ExecuteChildWorkflow(ctx, ChildWorkflow)
	return f.Get(ctx, nil)
}
```

子ワークフローのリトライは、再実行コストが大きくなることがあります（子が内部で多数のアクティビティを実行している等）。「どの粒度でリトライするか」は設計判断です。

---

## 5. 実践的なリトライ設定例

ここからは「外部 API 呼び出し」と「DB 操作」を題材に、設定の落としどころを示します。

### 5.1 例1：外部 API 呼び出し（5xx/タイムアウトはリトライ、4xx は基本リトライしない）

外部 API は、瞬断・一時的な混雑で失敗することがあります。一方で `400 Bad Request` のような入力起因の失敗はリトライしても改善しません。

#### 推奨の考え方

- **短めの InitialInterval + 指数バックオフ**
- **MaximumAttempts は「相手の SLO」「こちらの許容待ち時間」に合わせる**
- **リトライしないエラーを明示する**（NonRetryable）

Temporal の Go SDK では、アクティビティ内で返すエラーを **non-retryable** にできます。

```go
import (
	"context"
	"errors"
	"net/http"

	"go.temporal.io/sdk/temporal"
)

var ErrBadRequest = errors.New("bad request")

func CallExternalAPIActivity(ctx context.Context, url string) (string, error) {
	// 例：HTTP 呼び出し（擬似）
	respStatus := http.StatusBadRequest // 仮

	switch {
	case respStatus >= 500:
		// 5xx はリトライ対象にしたいので通常の error を返す
		return "", errors.New("upstream 5xx")
	case respStatus == 429:
		// レート制限もリトライ対象になり得る（バックオフ長め推奨）
		return "", errors.New("rate limited")
	case respStatus >= 400:
		// 4xx は入力起因のことが多いので non-retryable にする
		return "", temporal.NewNonRetryableApplicationError(
			"client error",
			"HTTP_4XX",
			ErrBadRequest,
		)
	default:
		return "ok", nil
	}
}
```

ワークフロー側はアクティビティオプションでリトライポリシーを設定します。

```go
func APIWorkflow(ctx workflow.Context, url string) (string, error) {
	ao := workflow.ActivityOptions{
		StartToCloseTimeout: 10 * time.Second,
		RetryPolicy: &temporal.RetryPolicy{
			InitialInterval:    500 * time.Millisecond,
			BackoffCoefficient: 2.0,
			MaximumInterval:    20 * time.Second,
			MaximumAttempts:    6, // だいたい 0.5 + 1 + 2 + 4 + 8 + 16 ≒ 31.5 秒規模
		},
	}
	ctx = workflow.WithActivityOptions(ctx, ao)

	var out string
	if err := workflow.ExecuteActivity(ctx, CallExternalAPIActivity, url).Get(ctx, &out); err != nil {
		return "", err
	}
	return out, nil
}
```

> 補足：429（レート制限）は「リトライはするが間隔は長く」したいことが多いです。  
> 単一の RetryPolicy でまとめるか、429 のときだけ別アクティビティ／別ポリシーで呼ぶかは要件次第です。

---

### 5.2 例2：DB 操作（デッドロック/一時的な接続問題はリトライ、ユニーク制約違反はリトライしない）

DB は「トランザクション競合」「デッドロック」「コネクション断」など一過性の失敗があり、リトライが効く場面があります。一方で **ユニーク制約違反**などはリトライしても同じ結果になりがちです。

#### 推奨の考え方

- DB のリトライは **短めの待機**で数回、が現実的（長く粘るとロック競合が悪化することもある）
- **冪等性**を意識する（同じワークフローが同じアクティビティを複数回実行し得る）
  - 例：`INSERT` は `UPSERT` にする、あるいは一意キーで「同じ要求なら同じ結果」を返せるようにする

アクティビティ例（擬似）：

```go
import (
	"context"
	"errors"

	"go.temporal.io/sdk/temporal"
)

var (
	ErrUniqueViolation = errors.New("unique violation")
	ErrDeadlock        = errors.New("deadlock")
)

func WriteToDBActivity(ctx context.Context, userID string) error {
	// 擬似的に DB エラーを分類して返す
	dbErr := ErrUniqueViolation // 仮

	switch {
	case errors.Is(dbErr, ErrDeadlock):
		// 競合はリトライで解消する可能性がある
		return dbErr
	case errors.Is(dbErr, ErrUniqueViolation):
		// 設計次第：すでに存在するなら成功扱いにするのも手
		// ここでは non-retryable として扱う例
		return temporal.NewNonRetryableApplicationError(
			"unique constraint violation",
			"DB_UNIQUE_VIOLATION",
			dbErr,
		)
	default:
		return dbErr
	}
}
```

ワークフロー側のリトライ設定例：

```go
func DBWorkflow(ctx workflow.Context, userID string) error {
	ao := workflow.ActivityOptions{
		StartToCloseTimeout: 5 * time.Second,
		RetryPolicy: &temporal.RetryPolicy{
			InitialInterval:    200 * time.Millisecond,
			BackoffCoefficient: 2.0,
			MaximumInterval:    2 * time.Second,
			MaximumAttempts:    5, // 短期決戦
		},
	}
	ctx = workflow.WithActivityOptions(ctx, ao)

	return workflow.ExecuteActivity(ctx, WriteToDBActivity, userID).Get(ctx, nil)
}
```

---

## 6. どうやって「適切な」リトライ値を決めるか（実務の指針）

最後に、設定に迷ったときの現実的な指針をまとめます。

- **失敗の種類を分ける**
  - 入力不正・権限不足・業務ルール違反：リトライしない（non-retryable）
  - 瞬断・タイムアウト・一時的な 5xx：リトライする
- **“最大でどれくらい待てるか” を先に決める**
  - ユーザー体験／後続処理の締切（例：30秒、5分、1時間）から逆算して `MaximumAttempts` とバックオフを決める
- **外部 API は「呼びすぎない」方向に倒す**
  - `BackoffCoefficient` は 2.0 前後、`MaximumInterval` を設ける
- **DB は「短く数回」＋冪等性**
  - 長いバックオフで粘るより、競合を避ける設計（粒度、ロック、ユニークキー）を改善する方が効くことが多い
- **タイムアウトとセットで設計する**
  - 1回の試行の上限（`StartToCloseTimeout`）と、全体の許容時間（試行回数×待機）を整合させる

---

## まとめ

- Temporal のリトライは、主に **アクティビティ**（および必要に応じて **子ワークフロー**）に対して `RetryPolicy` を設定して実現するのが基本です。
- `RetryPolicy` の重要パラメータは次の4つ：
  - `InitialInterval`：最初の待機
  - `BackoffCoefficient`：指数バックオフ係数
  - `MaximumAttempts`：最大試行回数（初回含む）
  - `MaximumInterval`：待機時間の上限
- 実務では「リトライすべき失敗」と「しても無駄な失敗」を分け、後者は **non-retryable** として返すのが効果的です。

次に深掘りするなら、あなたの扱う依存先（外部 API / DB）の失敗パターンに合わせて「どのエラーを non-retryable にするか」「どのくらいの最大待ち時間を許容するか」を具体化し、ポリシーをテンプレ化すると運用が安定します。