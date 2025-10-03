# ============================================================================
# ReservationMailer Preview - メールプレビュー機能
# ============================================================================
# 開発環境でメールの見た目を確認するためのプレビュークラスです。
# http://localhost:3000/rails/mailers/reservation_mailer でアクセス可能
# 
# 使用方法：
# 1. rails server を起動
# 2. ブラウザで上記URLにアクセス
# 3. メールの見た目を確認・デバッグ
# ============================================================================

# Preview all emails at http://localhost:3000/rails/mailers/reservation_mailer
class ReservationMailerPreview < ActionMailer::Preview
  # TODO: プレビュー用のメソッドを追加する場合はここに記述
  # 例：
  # def booking_confirmation
  #   reservation = Reservation.first || FactoryBot.create(:reservation)
  #   ReservationMailer.booking_confirmation(reservation)
  # end
end
