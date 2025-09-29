class SheetsController < ApplicationController
  # シート（座席）に関する静的/紹介ページのコントローラー
  # 誰でも閲覧できる座席レイアウトのサンプルや、全劇場の座席規模サマリを表示します。
  skip_before_action :authenticate_user!, only: :index

  # GET /sheets
  # 表示内容:
  # - @theaters: 劇場 → スクリーン → シートを事前読込して名称順に一覧化
  # - @total_screens: 全劇場にまたがるスクリーン総数
  # - @total_seats: 全劇場・全スクリーンの座席総数
  # - @sample_layout_rows: 画面紹介用の簡易3x5レイアウト（A〜C列 × 1〜5番）
  def index
    # N+1 を避けるため screens と sheets を includes で一括読込
    @theaters = Theater.includes(screens: :sheets).order(:name)

    # 規模サマリ（ダッシュボード的な指標）
    @total_screens = @theaters.sum { |theater| theater.screens.size }
    @total_seats = @theaters.sum { |theater| theater.screens.sum { |screen| screen.sheets.size } }

    # UI説明用の簡易サンプル。実データとは独立している（固定3x5）
    @sample_layout_rows = ('A'..'C').map do |row|
      [row, (1..5).to_a]
    end
  end
end
