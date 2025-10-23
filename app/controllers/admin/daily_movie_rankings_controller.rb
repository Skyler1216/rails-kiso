module Admin
  class DailyMovieRankingsController < BaseController
    # ============================================================================
    # 人気作品ランキング履歴表示コントローラー
    # station 5,6の変更箇所
    # ============================================================================
    # このコントローラーは、管理者が日次で保存される人気作品ランキングの
    # スナップショット（過去のデータ）を閲覧するための画面を提供します。
    #
    # 【主な機能】
    # - 過去のランキングデータを日付別に表示
    # - 前日との順位変動（上がった・下がった）を表示
    # - 前日との予約数変動（増えた・減った）を表示
    # - 日付を選択して過去のランキングを確認
    # ============================================================================

    # ============================================================================
    # 人気作品ランキングの履歴表示
    # ============================================================================
    # このメソッドは、管理者画面でランキング履歴を表示するためのメイン処理です。
    # メソッドを細分化して可読性と保守性を向上させたバージョンです。
    #
    # 【処理の流れ】
    # 1. 利用可能な集計日一覧を取得
    # 2. 表示対象の日付を決定し、ランキングデータを構築、ナビゲーション用の前の日付を設定
    # 3. 順位変動と予約数変動の差分を計算・設定
    # 4. ナビゲーション用の次の日付を設定
    # ============================================================================
    def index
      # 1. 利用可能な集計日一覧を取得
      @available_dates = fetch_available_dates
      #  データが存在しない場合は処理を終了（ビュー側で空状態を描画）
      return if @available_dates.empty?

      # 2. 表示対象の日付を決定し、ランキングデータを構築、ナビゲーション用の前の日付を設定
      @selected_date = resolve_selected_date(@available_dates, params[:date])
      @rankings, previous_rankings, @previous_date = build_rankings(@selected_date, @available_dates)

      # 3. 順位変動と予約数変動の差分を計算・設定
      assign_differences(@rankings, previous_rankings)

      # 4. ナビゲーション用の次の日付を設定
      @next_date = next_available_date(@available_dates, @selected_date)
    end

    private

    # ============================================================================
    # 利用可能な集計日取得メソッド
    # ============================================================================
    # DailyMovieRankingテーブルから重複を除いた集計日を降順で取得します。
    # 最新の日付が最初に来るようにソートされています。
    #
    # 【処理内容】
    # - distinct: 重複する日付を除去
    # - order(aggregated_on: :desc): 日付を降順（新しい順）でソート
    # - pluck(:aggregated_on): 日付のみを配列として取得
    #
    # 【戻り値の例】
    # [2024-01-15, 2024-01-14, 2024-01-13, ...]
    # ============================================================================
    def fetch_available_dates
      DailyMovieRanking
        .distinct
        .order(aggregated_on: :desc)
        .pluck(:aggregated_on)
    end

    # ランキングデータ構築メソッド
    # ============================================================================
    # 選択された日付と前日のランキングデータを取得し、
    # ランキングデータを取得してビューで扱いやすい形に整えます。
    #
    # 【処理の流れ】
    # 1. 前日（比較対象）の日付を取得
    # 2. 前日のランキングデータを取得（存在する場合のみ）
    # 3. 現在のランキングデータを取得
    # 4. 現在と前日のランキングをそのまま返し、ビューで利用できるようにする
    #
    # @param selected_date [Date] 選択された集計日
    # @param available_dates [Array<Date>] 利用可能な集計日一覧
    # @return [Array] [現在のランキング, 前日のランキング, 前日の日付] の配列
    # ============================================================================
    def build_rankings(selected_date, available_dates)
      # 前日（比較対象）の日付を取得
      previous_date = previous_available_date(available_dates, selected_date)

      # 前日のランキングデータを取得（存在する場合のみ）
      previous_rankings = previous_date ? fetch_rankings(previous_date) : []

      # 現在のランキングデータを取得
      current_rankings = fetch_rankings(selected_date)

      # 現在のランキングデータ、前日のランキングデータ、前日の日付を配列として返す
      # ここでは、例えば、こんな感じの配列が返される。
      # [
      #   [# 1番目の要素: 現在のランキング
      #     { movie_id: 1, rank_position: 1, reservation_count: 100 },
      #     { movie_id: 2, rank_position: 2, reservation_count: 80 },
      #     { movie_id: 3, rank_position: 3, reservation_count: 60 }
      #   ],
      #   [# 2番目の要素: 前日のランキング
      #     { movie_id: 1, rank_position: 2, reservation_count: 90 },
      #     { movie_id: 2, rank_position: 1, reservation_count: 95 },
      #     { movie_id: 3, rank_position: 3, reservation_count: 55 }
      #   ],
      #   # 3番目の要素: 前日の日付
      #   Date.parse("2024-01-14")
      # ]
      [current_rankings, previous_rankings, previous_date]
    end

    # ============================================================================
    # 日付解決メソッド
    # ============================================================================
    # URLパラメータで指定された日付を検証し、有効な日付を返します。
    # 無効な日付の場合は最新の集計日を返し、フラッシュメッセージを表示します。
    #
    # 【処理内容】
    # 1. パラメータが空の場合は最新の集計日を返す
    # 2. 日付文字列をDateオブジェクトに変換
    # 3. 利用可能な日付に含まれているかチェック
    # 4. 存在しない集計日が指定された場合はフラッシュメッセージを表示
    # 5. 日付の形式が正しくない場合はエラーメッセージを表示
    #
    # 【エラーハンドリング】
    # - ArgumentError: 日付の形式が正しくない場合
    # - 存在しない日付: 利用可能な日付に含まれていない場合
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
    #
    # 【N+1問題とは】
    # - 1回のクエリで取得したデータに対して、
    #   各レコードごとに追加のクエリを実行してしまう問題
    # - 例: ランキング10件を取得後、各映画の詳細情報を10回クエリ実行
    # - includes(:movie)により、映画情報も事前に取得して解決
    #
    # 【処理内容】
    # - includes(:movie): 映画情報を事前読み込み（N+1問題回避）
    # - where(aggregated_on: target_date): 指定日付のデータのみ取得
    # - order(:rank_position): 順位順でソート
    # - to_a: 配列として取得（データベースアクセスを完了）
    # ============================================================================
    def fetch_rankings(target_date)
      DailyMovieRanking
        .includes(:movie) # 映画情報を事前読み込み（N+1問題回避）
        .where(aggregated_on: target_date) # 指定日付のデータのみ取得
        .order(:rank_position) # 順位順でソート
        .to_a # 配列として取得
    end

    # ============================================================================
    # 順位変動差分計算メソッド
    # ============================================================================
    # 現在のランキングと前日のランキングを比較し、
    # 各映画の順位変動（前日比）を計算します。
    #
    # 【計算方法】
    # 前日の順位 - 現在の順位 = 変動数
    # - 正の値: 順位上昇（例: 5位→3位 = +2）
    # - 負の値: 順位下降（例: 3位→5位 = -2）
    # - nil: 前日データなし（新規ランクイン）
    #
    # 【戻り値の例】
    # { 1 => +2, 2 => -1, 3 => nil }
    # 映画ID1は2位上昇、映画ID2は1位下降、映画ID3は新規ランクイン
    #
    # @param current_rankings [Array] 現在のランキングデータ
    # @param previous_rankings [Array] 前日のランキングデータ
    # @return [Hash] { movie_id => 順位変動数 } のハッシュ
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
    #
    # 【計算方法】
    # 現在の予約数 - 前日の予約数 = 変動数
    # - 正の値: 予約数増加（例: 100件→120件 = +20）
    # - 負の値: 予約数減少（例: 120件→100件 = -20）
    # - nil: 前日データなし（新規ランクイン）
    #
    # 【戻り値の例】
    # { 1 => +20, 2 => -5, 3 => nil }
    # 映画ID1は20件増加、映画ID2は5件減少、映画ID3は新規ランクイン
    #
    # @param current_rankings [Array] 現在のランキングデータ
    # @param previous_rankings [Array] 前日のランキングデータ
    # @return [Hash] { movie_id => 予約数変動 } のハッシュ
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
    #
    # 【配列の構造例】
    # available_dates = [2024-01-15, 2024-01-14, 2024-01-13, ...]
    # インデックス:      [0,           1,           2,           ...]
    #
    # 現在が2024-01-14（インデックス1）の場合、
    # 前の日付は2024-01-13（インデックス2）
    #
    # @param available_dates [Array<Date>] 利用可能な集計日一覧（降順）
    # @param current [Date] 現在の日付
    # @return [Date, nil] 前の日付（存在しない場合はnil）
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
    #
    # 【配列の構造例】
    # available_dates = [2024-01-15, 2024-01-14, 2024-01-13, ...]
    # インデックス:      [0,           1,           2,           ...]
    #
    # 現在が2024-01-14（インデックス1）の場合、
    # 次の日付は2024-01-15（インデックス0）
    #
    # @param available_dates [Array<Date>] 利用可能な集計日一覧（降順）
    # @param current [Date] 現在の日付
    # @return [Date, nil] 次の日付（存在しない場合はnil）
    # ============================================================================
    def next_available_date(available_dates, current)
      index = available_dates.index(current)

      # インデックスが存在し、正の値（前の要素が存在する）場合のみ返す
      return nil unless index&.positive?

      available_dates[index - 1]
    end

    # ============================================================================
    # 差分データ設定メソッド
    # ============================================================================
    # 現在のランキングと前日のランキングを比較し、
    # 順位変動と予約数変動の差分をインスタンス変数に設定します。
    # ビューで前日比の表示に使用されるデータを準備します。
    #
    # 【設定する変数】
    # - @rankings_diff: 順位変動の差分ハッシュ
    # - @reservation_diff: 予約数変動の差分ハッシュ
    #
    # 【使用例】
    # ビューで「↑2位」「↓1位」「+20件」「-5件」などの表示に使用
    #
    # @param current_rankings [Array] 現在のランキングデータ
    # @param previous_rankings [Array] 前日のランキングデータ
    # ============================================================================
    def assign_differences(current_rankings, previous_rankings)
      # 順位変動の差分を計算・設定
      @rankings_diff = build_rank_differences(current_rankings, previous_rankings)

      # 予約数変動の差分を計算・設定
      @reservation_diff = build_reservation_differences(current_rankings, previous_rankings)
    end
  end
end
