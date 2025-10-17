module DailyMovieRankings
  # ============================================================================
  # ランキングスナップショットビルダー
  # station 5,6の変更箇所
  # ============================================================================
  # 日次ランキングデータの整合性を保つためのスナップショット構築サービスです。
  #
  # 【主な機能】
  # 1. 現在のランキングデータと過去のランキングデータを統合
  # 2. 過去にランキングに含まれていたが現在は含まれていない作品の表示
  # 3. 現在上映中または過去にランキングに含まれていた作品の一覧表示
  # 4. 予約数0の作品も含めた完全なランキングの構築
  #
  # 【処理の流れ】
  # 1. 現在のランキングをソート
  # 2. 過去のランキングから現在に含まれていない作品をプレースホルダーとして追加
  # 3. 候補映画（過去ランキング履歴 + 現在上映中）から現在・過去に含まれていない作品を追加
  # 4. 最終的なランキングをソートして返す
  # ============================================================================
  class SnapshotBuilder
    # 処理結果を格納する構造体
    # current: 現在のランキング（正規化済み）
    # previous: 前日のランキング（ソート済み）
    Result = Struct.new(:current, :previous, keyword_init: true)

    # クラスメソッドとして呼び出し可能にする
    def self.call(...)
      new(...).call
    end

    # 初期化
    # @param current_rankings [Array] 現在のランキングデータ
    # @param previous_rankings [Array] 前日のランキングデータ
    # @param target_date [Date] 対象日付
    def initialize(current_rankings:, previous_rankings:, target_date:)
      @current_rankings = Array(current_rankings) # 配列として正規化
      @previous_rankings = Array(previous_rankings) # 配列として正規化
      @target_date = target_date
    end

    # メイン処理：スナップショットの構築
    def call
      Result.new(
        current: build_current_snapshot, # 現在のランキングを正規化
        previous: sort(@previous_rankings) # 前日のランキングをソート
      )
    end

    private

    # インスタンス変数の読み取り専用アクセサ
    attr_reader :current_rankings, :previous_rankings, :target_date

    # ============================================================================
    # 現在のランキングスナップショット構築メソッド
    # ============================================================================
    # 現在のランキングデータを正規化し、完全なスナップショットを作成します。
    # 処理の流れ：
    # 1. 現在のランキングをソート
    # 2. 過去のランキングから現在に含まれていない作品を追加
    # 3. 候補映画から現在・過去に含まれていない作品を追加
    # ============================================================================
    def build_current_snapshot
      # 1. 現在のランキングをソート
      sorted_current = sort(current_rankings)

      # 2. 過去のランキングから現在に含まれていない作品をプレースホルダーとして追加
      with_previous = merge_from_previous(sorted_current)

      # 3. 候補映画から現在・過去に含まれていない作品をプレースホルダーとして追加
      merge_from_candidate_movies(with_previous)
    end

    # ============================================================================
    # 過去ランキングからのマージメソッド
    # ============================================================================
    # 過去のランキングに含まれていたが、現在のランキングに含まれていない作品を
    # プレースホルダー（予約数0、適切な順位）として追加します。
    # これにより、過去に人気だった作品の現在の状況も確認できます。
    # ============================================================================
    def merge_from_previous(sorted_current)
      # 現在のランキングに含まれている映画IDを取得
      existing_ids = sorted_current.map(&:movie_id)

      # 次の順位を計算（現在のランキングの最大順位 + 1）
      next_rank_position = next_rank(sorted_current)

      # 過去のランキングから現在に含まれていない作品を抽出し、プレースホルダーを作成
      placeholders = previous_rankings.reject { |ranking| existing_ids.include?(ranking.movie_id) }
                                      .map do |ranking|
        # プレースホルダーを作成（予約数0、適切な順位）
        placeholder = build_placeholder(
          movie: ranking.movie,
          movie_id: ranking.movie_id,
          rank_position: next_rank_position
        )

        # 重複を避けるため、既存IDリストに追加
        existing_ids << ranking.movie_id

        # 次の順位をインクリメント
        next_rank_position += 1

        placeholder
      end

      # 現在のランキングとプレースホルダーを結合してソート
      sort(sorted_current + placeholders)
    end

    # ============================================================================
    # 候補映画からのマージメソッド
    # ============================================================================
    # 候補映画（過去にランキングに含まれていた + 現在上映中）から、
    # 現在・過去のランキングに含まれていない作品をプレースホルダーとして追加します。
    # これにより、新しく上映開始した作品や、過去に一度もランキングに含まれなかった作品も表示されます。
    # ============================================================================
    def merge_from_candidate_movies(sorted_current)
      # 現在のランキングに含まれている映画IDを取得
      existing_ids = sorted_current.map(&:movie_id)

      # 候補映画IDから既存のIDを除外
      remaining_ids = candidate_movie_ids - existing_ids

      # 追加する作品がない場合は現在のランキングをそのまま返す
      return sorted_current if remaining_ids.empty?

      # 残りの映画情報を一括取得（N+1問題回避）
      movies = Movie.where(id: remaining_ids).index_by(&:id)

      # 次の順位を計算
      next_rank_position = next_rank(sorted_current)

      # 残りの映画IDからプレースホルダーを作成
      placeholders = remaining_ids.filter_map do |movie_id|
        movie = movies[movie_id]
        next unless movie # 映画が存在しない場合はスキップ

        # プレースホルダーを作成（予約数0、適切な順位）
        placeholder = build_placeholder(
          movie: movie,
          movie_id: movie_id,
          rank_position: next_rank_position
        )

        # 次の順位をインクリメント
        next_rank_position += 1

        placeholder
      end

      # 現在のランキングとプレースホルダーを結合してソート
      sort(sorted_current + placeholders)
    end

    # ============================================================================
    # ランキングソートメソッド
    # ============================================================================
    # ランキングデータを適切な順序でソートします。
    # ソート条件：
    # 1. 予約数0の作品を最後に配置
    # 2. 順位順（小さい順）
    # 3. 同じ順位の場合は映画ID順
    # ============================================================================
    def sort(rankings)
      rankings.sort_by do |ranking|
        [
          ranking.reservation_count.zero? ? 1 : 0, # 予約数0の作品を最後に
          ranking.rank_position || Float::INFINITY, # 順位順（nilは最後に）
          ranking.movie_id # 映画ID順（安定ソート）
        ]
      end
    end

    # ============================================================================
    # プレースホルダー作成メソッド
    # ============================================================================
    # 指定された映画のプレースホルダー（予約数0のランキングエントリ）を作成します。
    # これにより、過去にランキングに含まれていた作品や新しく上映開始した作品も
    # ランキング履歴に表示されるようになります。
    # ============================================================================
    def build_placeholder(movie:, movie_id:, rank_position:)
      DailyMovieRanking.new(
        aggregated_on: target_date,  # 対象日付
        movie: movie,                # 映画オブジェクト
        movie_id: movie_id,          # 映画ID
        reservation_count: 0,        # 予約数は0
        rank_position: rank_position # 指定された順位
      )
    end

    # ============================================================================
    # 次の順位計算メソッド
    # ============================================================================
    # 指定されたランキングリストの次の順位を計算します。
    # 既存の最大順位 + 1 を返します。
    # ============================================================================
    def next_rank(rankings)
      # 既存の順位の最大値を取得し、+1して次の順位を返す
      (rankings.map(&:rank_position).compact.max || 0) + 1
    end

    # ============================================================================
    # 候補映画ID取得メソッド
    # ============================================================================
    # ランキングに含めるべき候補映画のIDリストを取得します。
    # 候補映画は以下の条件を満たすもの：
    # 1. 過去にランキングに含まれていた映画
    # 2. 現在上映中の映画
    #
    # メモ化により、同じインスタンス内での重複クエリを回避します。
    # ============================================================================
    def candidate_movie_ids
      @candidate_movie_ids ||= begin
        # 過去にランキングに含まれていた映画IDを取得
        historical_ids = DailyMovieRanking.distinct.pluck(:movie_id)

        # 現在上映中の映画IDを取得
        active_ids = Movie.where(is_showing: true).pluck(:id)

        # 両方を結合して重複を除去
        (historical_ids + active_ids).uniq
      end
    end
  end
end
