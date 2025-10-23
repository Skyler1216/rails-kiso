require 'rails_helper'

# ============================================================================
# DailyMovieRankingモデルのテストファイル
# ============================================================================
# このファイルは、映画の日次ランキングデータが正しく動作するかをテストします。
#
# 【テストの目的】
# 1. データの入力チェック（バリデーション）が正しく動作するか
# 2. データの検索機能（スコープ）が正しく動作するか
#
# 【初心者向けの説明】
# - テストとは：プログラムが期待通りに動くかを自動で確認する仕組み
# - バリデーション：データが正しい形式かどうかをチェックする機能
# - スコープ：データベースから条件に合うデータを取得する機能
# ============================================================================
RSpec.describe DailyMovieRanking, type: :model do
  # ============================================================================
  # バリデーションテスト（データの入力チェック）
  # ============================================================================
  # 映画ランキングのデータが正しい形式で入力されているかをテストします。
  # 例：日付が空でないか、予約数がマイナスでないか、など
  # ============================================================================
  describe 'validations' do
    # テスト1：集計日（日付）が必須であることを確認
    it '集計日が必須であること' do
      # 日付を空にしてランキングデータを作成
      ranking = build(:daily_movie_ranking, aggregated_on: nil)

      # データが無効（エラーがある）であることを確認
      expect(ranking).not_to be_valid
      # エラーメッセージに「空白はダメ」という内容が含まれていることを確認
      expect(ranking.errors.details[:aggregated_on]).to include(error: :blank)
    end

    # テスト2：予約数が0以上であることを確認
    it '予約数が0以上であること' do
      # 予約数を-1（マイナス）にしてランキングデータを作成
      ranking = build(:daily_movie_ranking, reservation_count: -1)

      # データが無効（エラーがある）であることを確認
      expect(ranking).not_to be_valid
      # エラーメッセージに「0以上でないとダメ」という内容が含まれていることを確認
      expect(ranking.errors.details[:reservation_count]).to include(hash_including(error: :greater_than_or_equal_to))
    end

    # テスト3：順位が1以上であることを確認
    it '順位が1以上であること' do
      # 順位を0にしてランキングデータを作成
      ranking = build(:daily_movie_ranking, rank_position: 0)

      # データが無効（エラーがある）であることを確認
      expect(ranking).not_to be_valid
      # エラーメッセージに「1以上でないとダメ」という内容が含まれていることを確認
      expect(ranking.errors.details[:rank_position]).to include(hash_including(error: :greater_than))
    end
  end
end
