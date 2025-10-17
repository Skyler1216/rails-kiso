module Admin
  class DailyMovieRankingsController < BaseController
    # ============================================================================
    # 人気作品ランキング履歴表示コントローラー
    # station 5,6の変更箇所
    # ============================================================================
    # 日次で保存される人気作品ランキングのスナップショットを閲覧し、
    # 過去との順位・予約数の差分を確認できる管理画面を提供します。
    # ============================================================================

    # 人気作品ランキングの履歴表示
    def index
      # 1. 利用可能な集計日一覧を取得（最新順でソート）
      # DailyMovieRankingテーブルから重複を除いた集計日を降順で取得
      @available_dates = DailyMovieRanking
                         .distinct
                         .order(aggregated_on: :desc)
                         .pluck(:aggregated_on)

      # 2. データが存在しない場合の早期リターン
      # ランキングデータがまだ存在しない場合は空の状態でビューに渡す
      if @available_dates.empty?
        @selected_date = nil
        @rankings = []
        return
      end

      # 3. 表示対象の日付を決定
      # URLパラメータで指定された日付を検証し、有効な日付を選択
      @selected_date = resolve_selected_date(@available_dates, params[:date])
      
      # 4. 選択された日付のランキングデータを取得
      # 映画情報も一緒に読み込んでN+1問題を回避
      @rankings = fetch_rankings(@selected_date)

      # 5. 前日（比較対象）の日付とランキングデータを取得
      # 順位変動や予約数変動の計算に使用
      previous_date = previous_available_date(@available_dates, @selected_date)
      @previous_rankings = previous_date ? fetch_rankings(previous_date) : []

      # 6. スナップショットビルダーでランキングデータを正規化
      # 過去のデータと現在のデータを統合し、一貫性のあるランキングを作成
      # これにより、過去にランキングに含まれていたが現在は含まれていない作品も表示される
      snapshot = DailyMovieRankings::SnapshotBuilder.call(
        current_rankings: @rankings,
        previous_rankings: @previous_rankings,
        target_date: @selected_date
      )

      # 7. 正規化されたランキングデータを取得
      @rankings = snapshot.current
      @previous_rankings = snapshot.previous

      # 8. 順位変動と予約数変動の差分を計算
      # ビューで前日比の表示に使用される
      @rankings_diff = build_rank_differences(@rankings, @previous_rankings)
      @reservation_diff = build_reservation_differences(@rankings, @previous_rankings)

      # 9. ナビゲーション用の前後の日付を設定
      # ビューで「前の日付」「次の日付」ボタンの表示制御に使用
      @next_date = next_available_date(@available_dates, @selected_date)
      @previous_date = previous_date
    end

    private

    # ============================================================================
    # 日付解決メソッド
    # ============================================================================
    # URLパラメータで指定された日付を検証し、有効な日付を返します。
    # 無効な日付の場合は最新の集計日を返し、フラッシュメッセージを表示します。
    # ============================================================================
    def resolve_selected_date(available_dates, requested_date)
      # パラメータが空の場合は最新の集計日を返す
      return available_dates.first if requested_date.blank?

      # 日付文字列をDateオブジェクトに変換
      parsed_date = Date.parse(requested_date)
      
      # 利用可能な日付に含まれているかチェック
      return parsed_date if available_dates.include?(parsed_date)

      # 存在しない集計日が指定された場合
      flash.now[:alert] = '存在しない集計日が指定されました。最新の集計日を表示します。'
      available_dates.first
    rescue ArgumentError
      # 日付の形式が正しくない場合
      flash.now[:alert] = '集計日の形式が正しくありません。最新の集計日を表示します。'
      available_dates.first
    end

    # ============================================================================
    # ランキングデータ取得メソッド
    # ============================================================================
    # 指定された日付のランキングデータを映画情報と一緒に取得します。
    # includes(:movie)によりN+1問題を回避しています。
    # ============================================================================
    def fetch_rankings(target_date)
      DailyMovieRanking
        .includes(:movie)  # 映画情報を事前読み込み（N+1問題回避）
        .for_date(target_date)  # 指定日付のデータのみ取得
        .ordered  # 順位順でソート
        .to_a  # 配列として取得
    end

    # ============================================================================
    # 順位変動差分計算メソッド
    # ============================================================================
    # 現在のランキングと前日のランキングを比較し、
    # 各映画の順位変動（前日比）を計算します。
    # 戻り値: { movie_id => 順位変動数 } のハッシュ
    # 正の値: 順位上昇、負の値: 順位下降、nil: 前日データなし
    # ============================================================================
    def build_rank_differences(current_rankings, previous_rankings)
      # 前日のランキングをmovie_idでインデックス化（高速検索のため）
      previous_map = previous_rankings.index_by(&:movie_id)
      
      # 現在のランキングを順番に処理
      current_rankings.each_with_object({}) do |ranking, hash|
        previous_ranking = previous_map[ranking.movie_id]
        
        # 前日のランキングが存在する場合のみ差分を計算
        # 前日の順位 - 現在の順位 = 変動数（正の値で上昇、負の値で下降）
        hash[ranking.movie_id] = previous_ranking ? previous_ranking.rank_position - ranking.rank_position : nil
      end
    end

    # ============================================================================
    # 予約数変動差分計算メソッド
    # ============================================================================
    # 現在のランキングと前日のランキングを比較し、
    # 各映画の予約数変動（前日比）を計算します。
    # 戻り値: { movie_id => 予約数変動 } のハッシュ
    # 正の値: 予約数増加、負の値: 予約数減少、nil: 前日データなし
    # ============================================================================
    def build_reservation_differences(current_rankings, previous_rankings)
      # 前日のランキングをmovie_idでインデックス化（高速検索のため）
      previous_map = previous_rankings.index_by(&:movie_id)
      
      # 現在のランキングを順番に処理
      current_rankings.each_with_object({}) do |ranking, hash|
        previous_ranking = previous_map[ranking.movie_id]
        
        # 前日のランキングが存在する場合のみ差分を計算
        # 現在の予約数 - 前日の予約数 = 変動数（正の値で増加、負の値で減少）
        hash[ranking.movie_id] = previous_ranking ? ranking.reservation_count - previous_ranking.reservation_count : nil
      end
    end

    # ============================================================================
    # 前の利用可能日付取得メソッド
    # ============================================================================
    # 現在の日付より古い（過去の）利用可能な日付を取得します。
    # available_datesは降順（新しい順）でソートされているため、
    # 現在のインデックス + 1 が前の日付になります。
    # ============================================================================
    def previous_available_date(available_dates, current)
      index = available_dates.index(current)
      
      # インデックスが存在し、次の要素（前の日付）が存在する場合のみ返す
      return nil unless index && (index + 1) < available_dates.size

      available_dates[index + 1]
    end

    # ============================================================================
    # 次の利用可能日付取得メソッド
    # ============================================================================
    # 現在の日付より新しい（未来の）利用可能な日付を取得します。
    # available_datesは降順（新しい順）でソートされているため、
    # 現在のインデックス - 1 が次の日付になります。
    # ============================================================================
    def next_available_date(available_dates, current)
      index = available_dates.index(current)
      
      # インデックスが存在し、正の値（前の要素が存在する）場合のみ返す
      return nil unless index&.positive?

      available_dates[index - 1]
    end
  end
end
