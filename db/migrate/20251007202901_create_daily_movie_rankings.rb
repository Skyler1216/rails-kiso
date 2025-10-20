# ============================================================================
# 日次映画ランキングテーブル作成マイグレーション
# station 5,6の変更箇所
# ============================================================================
# 映画の人気度を日次で集計・保存するためのテーブルを作成します。
# 予約数に基づいて映画のランキングを管理し、トップページでの表示に使用します。
# daily_movie_rankingsテーブルのカラム
#   - aggregated_on: 集計対象日（YYYY-MM-DD形式）
#   - reservation_count: その日の予約数（人気度の指標）
#   - rank_position: ランキング順位（1位、2位、3位...）
#   - movie_id: 映画への外部キー参照
#   - created_at(timestamp): 作成日時
#   - updated_at(timestamp): 更新日時
# ============================================================================
class CreateDailyMovieRankings < ActiveRecord::Migration[7.1]
  # changeメソッドを使うと、Railsが自動的にロールバック用の処理を生成してくれる
  def change
    # 日次映画ランキングテーブルを作成
    create_table :daily_movie_rankings do |t|
      # 集計対象日（YYYY-MM-DD形式）
      # null: false で必須項目として設定
      # dateは「日付を保存するためのデータ型」（YYYY-MM-DD）
      t.date :aggregated_on, null: false
      
      # その日の予約数（人気度の指標）
      # null: false, default: 0 で初期値を0に設定
      # integerは「整数を保存するためのデータ型」
      t.integer :reservation_count, null: false, default: 0
      
      # ランキング順位（1位、2位、3位...）
      # null: false で必須項目として設定
      # integerは「整数を保存するためのデータ型」
      # 0は無効な値、必ず計算で決定 → defaultなし
      t.integer :rank_position, null: false
      
      # 映画への外部キー参照
      # null: false, foreign_key: true で映画テーブルとの関連を強制
      # referencesは「外部キーを保存するためのデータ型」
      t.references :movie, null: false, foreign_key: true

      # 作成日時・更新日時を自動管理
      # timestampsは「作成日時・更新日時を自動管理するためのデータ型」
      t.timestamps
    end

    # テーブルにインデックスを追加（パフォーマンス最適化）
    
    # 複合ユニークインデックス：同じ日付・同じ映画の重複を防ぐ
    # 例：2024-01-01の映画Aのランキングは1つだけ存在可能
    add_index :daily_movie_rankings, [:aggregated_on, :movie_id], 
              unique: true, 
              name: 'index_daily_rankings_on_date_and_movie'
    
    # 複合インデックス：日付とランキング順位での高速検索用
    # 例：「2024-01-01の1位〜10位の映画を取得」が高速化
    add_index :daily_movie_rankings, [:aggregated_on, :rank_position], 
              name: 'index_daily_rankings_on_date_and_rank'
  end
end
