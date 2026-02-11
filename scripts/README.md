# Scripts

このディレクトリには、実験に使用するJuliaスクリプトが含まれています。

## gendata.jl

設定ファイルから円データを生成します。Poisson Disk Sampling (PDS) を使用して、指定された領域に均等に分散した円を生成します。

**使い方:**
```bash
julia gendata.jl <config.json> <output.json>
```

**例:**
```bash
# 単一のデータセットを生成
julia gendata.jl dataconfig/config010.json data/data010.json

# 複数のサンプルを生成 (config.json に "samples": 50 が設定されている場合)
julia gendata.jl dataconfig/config010.json data/data010.json
# → data010-001.json, data010-002.json, ..., data010-050.json を生成
```

**入力:**
- `config.json`: 領域、PDS半径、円の半径範囲、シード値、サンプル数を指定

**出力:**
- `output.json`: 生成された円データ (中心座標、半径を含む)

---

## bdd_solver.jl

BDD (Binary Decision Diagram) を用いた信頼性解析ソルバー。複数の円領域の配置によるカバレッジを計算します。

**使い方:**
```bash
julia bdd_solver.jl <data.json> [sortmode]
```

**例:**
```bash
# デフォルトsortmode (angles_from_center) で実行
julia bdd_solver.jl data/data010-001.json

# 指定したsortmodeで実行
julia bdd_solver.jl data/data010-001.json origin
```

**sortmode オプション:**
- `origin`: 原点 (0,0) からの距離でソート
- `center`: 中心 (0.5,0.5) からの距離でソート
- `random`: ランダムにソート
- `xcoordinate`: X座標でソート
- `ycoordinate`: Y座標でソート
- `angles_from_origin`: 原点からの角度でソート
- `angles_from_center`: 中心からの角度でソート (デフォルト)

**出力:**
- JSON形式で以下を出力:
  - ノード数情報 (phi1, phi2のDAG サイズ)
  - 信頼度範囲 (下限と上限)
  - 計算時間とメモリ使用量

---

## branch_and_bound.jl

Branch and Boundアルゴリズムを用いた組合せ最適化ソルバー。Voronoi分割との組み合わせで最適な円配置を探索します。

**使い方:**
```bash
julia branch_and_bound.jl <data.json>
```

**例:**
```bash
julia branch_and_bound.jl data/data040-001.json
```

**出力:**
- 見つかったパスベクトル（円の選択パターン）と計算時間を表示

---

## run_bdd_batch.jl

複数のデータセットに対して BDD ソルバーをバッチ実行し、結果をCSVに保存します。

**使い方:**
```bash
julia run_bdd_batch.jl <prefix> [start_idx] [end_idx] [sortmode] [output.csv]
```

**例:**
```bash
# data040-001.json から data040-050.json を処理 (angles_from_center でソート)
julia run_bdd_batch.jl data/data040 1 50 angles_from_center result_bdd_data040.csv

# デフォルト値を使用
julia run_bdd_batch.jl data/data040
```

**出力 (CSV):**
- datafile: データファイル名
- sortmode: 使用したソート方法
- circles: 円の数
- convergence: 収束フラグ
- level: 分割レベル
- nodes_phi1, nodes_phi2: BDD ノード数
- peak_nodes, total_nodes: ピークおよび総ノード数
- memory_mb: メモリ使用量 (MB)
- solve_time_sec: 計算時間 (秒)
- prob_time_varphi2_sec, prob_time_varphi1_sec: 確率計算時間
- reliability_lb, reliability_ub: 信頼度の下限と上限

---

## run_bnb_batch.jl

複数のデータセットに対して Branch and Bound ソルバーをバッチ実行し、結果をCSVに保存します。

**使い方:**
```bash
julia run_bnb_batch.jl <prefix> [start_idx] [end_idx] [output.csv]
```

**例:**
```bash
# data020-001.json から data020-050.json を処理
julia run_bnb_batch.jl data/data020 1 50 result_bnb_data020.csv

# デフォルト値を使用
julia run_bnb_batch.jl data/data020
```

**出力 (CSV):**
- datafile: データファイル名
- circles: 円の数
- path_vectors: 見つかったパスベクトルの数
- solve_time_sec: 計算時間 (秒)

---

## ncircle.jl

各データセットグループ (data008, data009, ...) のサークル数統計を計算・表示します。

**使い方:**
```bash
julia ncircle.jl [data_directory]
```

**例:**
```bash
# デフォルト (data フォルダ)
julia ncircle.jl

# 指定したディレクトリ
julia ncircle.jl data
```

**出力:**
- DataName: データセット名
- Min: 最小サークル数
- Max: 最大サークル数
- Mean: 平均サークル数
- Count: サンプル数

---

## plot_circles.jl

円データを可視化します。

**使い方:**
```bash
julia plot_circles.jl <data.json> [output.png]
```

**例:**
```bash
julia plot_circles.jl data/data010-001.json circles.png
```

**出力:**
- PNG形式の画像ファイル（円の配置を視覚化）

---

## Docker での実行

全てのスクリプトは Docker イメージ `cudd-julia` 内で実行することを推奨します：

```bash
# BDD ソルバーをバッチ実行
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data040 1 50

# Branch and Bound ソルバーをバッチ実行
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bnb_batch.jl data/data040 1 50

# 単一実行
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/bdd_solver.jl data/data010-001.json
```
