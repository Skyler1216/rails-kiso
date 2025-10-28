# ============================================================================
# DailyMovieRankings::Refresher - 日次映画ランキング更新サービス
# station 5,6の変更箇所
# ============================================================================
# 指定した日付の映画ランキングを集計・更新するサービスです。
# 過去N日間の予約数に基づいて映画の人気度を計算し、ランキングを生成します。
# ============================================================================
module DailyMovieRankings
  class Refresher
    # デフォルトの集計期間（過去30日間）
    LOOKBACK_DAYS = 30

    # クラスメソッドでインスタンス化と実行を一括処理。１行で済む。
    # 使用例: DailyMovieRankings::Refresher.call(target_date: Date.current)
    def self.call(...)
      new(...).call
    end

    # 初期化処理　initialize は new とセットで動く
    # @param target_date [Date] 集計対象日（デフォルト: 今日）
    # @param lookback_days [Integer] 集計期間（デフォルト: 30日）
    def initialize(target_date: Time.zone.today, lookback_days: LOOKBACK_DAYS)
      # .to_date … 「日付（Dateオブジェクト）」に変換
      @target_date = target_date.to_date
      # .to_i … 「整数」に変換
      # [lookback_days.to_i, 1].max … 「lookback_days.to_i」と「1」のうち、大きい方を選択し、最小値1を保証（負の値や0を防ぐ）
      @lookback_days = [lookback_days.to_i, 1].max
    end

    # メイン処理：ランキングの更新を実行
    # @return [Array] 作成されたランキングレコードの配列
    def call
      ApplicationRecord.transaction do
        # 既存のランキングデータを削除（重複を防ぐため）
        DailyMovieRanking.where(aggregated_on: target_date).delete_all

        # 新しいランキングデータを構築。build_rowsは、下で定義されている。
        rows = build_rows
        # もし、rowsが空の場合は、空の配列を返す。つまり、ランキングデータがない場合は、空の配列を返す。
        return [] if rows.empty?

        # 一括挿入でパフォーマンスを向上
        DailyMovieRanking.insert_all!(rows)
      end
    end

    private

    # インスタンス変数の読み取り専用アクセサ
    attr_reader :target_date, :lookback_days

    # ランキングデータの行を構築
    # @return [Array<Hash>] データベース挿入用のハッシュ配列
    #
    # 【処理の流れ】
    # 1. aggregated_countsから映画別予約数を取得
    #   例: [{ movie_id: 3, reservation_count: 52 }, { movie_id: 5, reservation_count: 48 }]
    #
    # 2. map.with_index(1).map でランキング順位を付与しつつ、データベース挿入用のハッシュに変換
    #   例: [{ aggregated_on: 2024-01-15, movie_id: 3, reservation_count: 52,
    #         rank_position: 1, created_at: now, updated_at: now }, ...]
    #
    # 3. DailyMovieRanking.insert_all!で一括挿入
    def build_rows
      # 一括挿入のため、全レコードで同じタイムスタンプを使用
      now = Time.current

      # 集計結果をランキング順位付きで変換
      aggregated_counts.map.with_index(1).map do |tuple, index|
        {
          aggregated_on: target_date, # 集計対象日
          movie_id: tuple[:movie_id],                     # 映画ID
          reservation_count: tuple[:reservation_count],   # 予約数
          rank_position: index,                          # ランキング順位（1位から開始）
          created_at: now,                               # 作成日時
          updated_at: now                                # 更新日時
        }
      end
    end

    # 映画別の予約数を集計
    # @return [Array<Hash>] 映画IDと予約数のハッシュ配列
    def aggregated_counts
      Reservation.joins(schedule: :movie) # 予約→スケジュール→映画の結合
                 .where(created_at: created_at_range) # 集計期間内の予約のみ
                 .group('movies.id') # 映画IDでグループ化
                 .select('movies.id AS movie_id, COUNT(*) AS reservation_count') # 映画IDと予約数を選択
                 .order('reservation_count DESC, movies.id ASC') # 予約数降順、映画ID昇順でソート
                 .map { |record| { movie_id: record.movie_id, reservation_count: record.reservation_count.to_i } }
    end

    # 集計期間の範囲を計算
    # @return [Range<Time>] 開始時刻から終了時刻までの範囲
    def created_at_range
      # 集計開始日: 対象日から(集計期間-1)日前
      start_time = (target_date - (lookback_days - 1)).beginning_of_day
      # 集計終了日: 対象日の終了時刻
      end_time = target_date.end_of_day
      start_time..end_time
    end
  end
end
