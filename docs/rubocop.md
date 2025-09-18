
# バッチ1：改行コード & 末尾空白系（基礎整形）

**TODOから外すCop**

- `Layout/EndOfLine: Enabled: false`（このブロックを削除）
- `Layout/TrailingWhitespace`
- `Layout/TrailingEmptyLines`

**実作業**

```bash
sudo apt-get install -y dos2unix
find . -type f -not -path "./.git/*" -exec dos2unix {} +
bundle exec rubocop -a
bundle exec rubocop
git add -A && git commit -m "style: normalize EOL to LF and remove trailing spaces/blank lines"

```

---

# バッチ2：スペース/インデント/空行の整形（ほぼ自動）

**TODOから外すCop（代表）**

- スペース類：`Layout/ExtraSpacing`、`Layout/SpaceAfterComma`、`Layout/SpaceBeforeComma`、`Layout/SpaceInside*`
- インデント類：`Layout/IndentationWidth`、`Layout/IndentationConsistency`、`Layout/FirstArgumentIndentation`、`Layout/MultilineMethodCallIndentation`
- 位置揃え：`Layout/EndAlignment`、`Layout/HashAlignment`
- 空行：`Layout/EmptyLineBetweenDefs`、`Layout/EmptyLinesAround*`

**実作業**

```bash
bundle exec rubocop -a
bundle exec rubocop
git add -A && git commit -m "style: fix spacing/indentation and empty-line layout cops"

```

---

# バッチ3：文字列・記法の統一（大量だけど安全）

**TODOから外すCop**

- `Style/StringLiterals`（※TODOに `Enabled: false` があるなら削除。`.rubocop.yml`で single_quotes を強制済み）
- `Style/StringLiteralsInInterpolation`
- `Style/PercentLiteralDelimiters`
- `Style/RedundantInterpolation`
- `Style/BlockComments`

**実作業**

```bash
bundle exec rubocop -a
git add -A && git commit -m "style: unify string quotes and tidy percent/interpolation/comment styles"

```

---

# バッチ4：GemfileとBundler（点数小・見た目キレイ）

**TODOから外すCop**

- `Bundler/OrderedGems`
- `Layout/SpaceInsidePercentLiteralDelimiters`（Gemfile対象が多い）

**実作業**

```bash
bundle exec rubocop -a Gemfile
bundle exec rubocop
git add -A && git commit -m "style: order gems in Gemfile and tidy percent literal delimiters"

```

---

# バッチ5：unsafe混在のStyle（個別に慎重対応）

**TODOから徐々に外すCop（ファイル単位推奨）**

- `Style/ClassAndModuleChildren`（名前空間の宣言スタイル変更。挙動影響に注意）
- `Style/RedundantFetchBlock`（`fetch` のデフォルト指定へ書き換え。副作用に注意）
- `Style/GlobalStdStream`（ログ出力先の書式変更）

**実作業（例：特定ファイルだけ）**

```bash
bundle exec rubocop -A app/controllers/admin/movies_controller.rb
# or 手で直してから
bundle exec rubocop
git add -A && git commit -m "style: adjust namespace/ENV fetch/stdout styles (manual review)"

```

---

# バッチ6：Metrics（設計リファクタ or ルール調整）

**対象Cop（例）**

- `Metrics/MethodLength`、`Metrics/BlockLength`、`Metrics/ClassLength`
- `Metrics/AbcSize`（TODOで Max: 27 に調整済み）

**方針**

1. 関心ごと分離・メソッド抽出・サービス層化で短縮。
2. 難所は `.rubocop.yml` で対象限定の緩和/除外：

```yaml
Metrics/MethodLength:
  Max: 25
  Exclude:
    - 'app/controllers/reservations_controller.rb'

```

**実作業**

```bash
# リファクタ → テスト/動作確認 → rubocop
bundle exec rubocop
git add -A && git commit -m "refactor: reduce method/block length to satisfy metrics cops"

```

---

# オプション：TODOの再生成でクリーンアップ

大きく直した後に、TODOを最新化したいときだけ：

```bash
bundle exec rubocop --auto-gen-config
git add .rubocop_todo.yml && git commit -m "chore: refresh rubocop_todo after fixes"

```

---

# 迷ったときの優先度

1. **バッチ1**（改行・末尾空白）
2. **バッチ2**（スペース/インデント/空行）
3. **バッチ3**（文字列・記法）
4. **バッチ4**（Gemfile）
5. **バッチ6**（Metrics：設計/リファクタ）
6. **バッチ5**（unsafe混在：個別に）

---

この順でやれば、見た目のノイズ→軽微整形→記法→周辺→設計、の順に綺麗に仕上がります。必要なら、次のバッチ用に「TODOから消すべきCop一覧」をあなたの最新ファイルに合わせてまた指示するよ。