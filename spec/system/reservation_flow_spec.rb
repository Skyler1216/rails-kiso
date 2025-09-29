require 'rails_helper'

RSpec.describe 'Reservation flow', type: :system do
  before do
    driven_by(:rack_test)
  end

  let!(:user) { create(:user, email: 'test@example.com', password: 'password123', password_confirmation: 'password123') }
  let!(:theater) { create(:theater, name: 'テスト劇場') }
  let!(:screen) { create(:screen, theater: theater, name: 'スクリーン1') }
  let!(:movie) { create(:movie, name: 'テスト映画') }
  let(:schedule_start_time) { 5.days.from_now.change(hour: 10, min: 0) }
  let!(:schedule) { create(:schedule, movie: movie, screen: screen, start_time: schedule_start_time) }
  let(:sheet1) { screen.sheets.find_by!(row: 'A', column: 1) }
  let(:sheet2) { screen.sheets.find_by!(row: 'A', column: 2) }

  describe '予約フロー' do
    before do
      sign_in user
    end

    it '映画詳細から予約まで完了できること' do
      # 映画詳細ページにアクセス
      visit movie_path(movie)

      # 劇場と日付を選択
      select theater.name, from: '劇場を選択'
      date_label = schedule_start_time.to_date.strftime('%Y年%m月%d日')
      select date_label, from: '日付を選択'
      click_button '上映スケジュールを表示'

      # スケジュールを選択して座席選択ページへ
      select '10:00～12:00 / スクリーン1', from: 'スケジュールを選択'
      click_button '座席を選ぶ'

      # 座席選択ページで座席をクリック
      expect(page).to have_content('Seat Selection')
      expect(page).to have_content('Seat Map')
      click_link 'A-1'

      # 予約フォームが表示される
      expect(page).to have_content('予約者情報')
      expect(page).to have_content('テスト映画')
      expect(page).to have_content('テスト劇場')
      expect(page).to have_content('スクリーン1')

      # 予約を確定
      expect {
        click_button '予約を確定する'
      }.to change(Reservation, :count).by(1)

      # 成功メッセージが表示される
      expect(page).to have_content('予約が完了しました')
    end

    it '重複予約を防げること' do
      # 既存の予約を作成
      create(:reservation, 
             schedule: schedule, 
             sheet: sheet1, 
             date: schedule_start_time.to_date.to_s,
             screen: screen)

      # 映画詳細ページにアクセス
      visit movie_path(movie)

      # 劇場と日付を選択
      select theater.name, from: '劇場を選択'
      date_label = schedule.start_time.to_date.strftime('%Y年%m月%d日')
      select date_label, from: '日付を選択'
      click_button '上映スケジュールを表示'

      # スケジュールを選択して座席選択ページへ
      select '10:00～12:00 / スクリーン1', from: 'スケジュールを選択'
      click_button '座席を選ぶ'

      # 予約済みの座席はクリックできない
      expect(page).not_to have_link('A-1')
      expect(page).to have_content('A-1') # 座席は表示されるがリンクではない

      # 空いている座席はクリックできる
      expect(page).to have_link('A-2')
    end

    it '予約フォームでバリデーションエラーが表示されること' do
      # 直接予約フォームにアクセス
      visit new_movie_schedule_reservation_path(movie, schedule, 
                                               sheet_id: sheet1.id, 
                                               date: schedule_start_time.to_date.to_s)

      # 無効な情報で予約を試行（hiddenフィールドを書き換えて日付を空にする）
      find("input[name='reservation[date]']", visible: false).set('')

      expect {
        click_button '予約を確定する'
      }.not_to change(Reservation, :count)

      expect(page).to have_content('入力内容に誤りがあります')
    end
  end

  describe 'ログインが必要な予約機能' do
    it 'ログインしていない場合は予約ページにアクセスできないこと' do
      visit new_movie_schedule_reservation_path(movie, schedule, 
                                               sheet_id: sheet1.id, 
                                               date: schedule_start_time.to_date.to_s)

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content('ログイン')
    end

    it 'ログイン後は予約ページにアクセスできること' do
      sign_in user
      visit new_movie_schedule_reservation_path(movie, schedule, 
                                               sheet_id: sheet1.id, 
                                               date: schedule_start_time.to_date.to_s)

      expect(page).to have_content('予約者情報')
    end
  end

  describe '座席選択ページ' do
    before do
      sign_in user
    end

    it '座席が正しく表示されること' do
      visit movie_path(movie)

      select theater.name, from: '劇場を選択'
      date_label = schedule.start_time.to_date.strftime('%Y年%m月%d日')
      select date_label, from: '日付を選択'
      click_button '上映スケジュールを表示'

      select '10:00～12:00 / スクリーン1', from: 'スケジュールを選択'
      click_button '座席を選ぶ'

      expect(page).to have_content('A-1')
      expect(page).to have_content('A-2')
      expect(page).to have_content('Seat Map')
    end

    it '選択した座席の情報が正しく表示されること' do
      visit movie_path(movie)

      select theater.name, from: '劇場を選択'
      date_label = schedule.start_time.to_date.strftime('%Y年%m月%d日')
      select date_label, from: '日付を選択'
      click_button '上映スケジュールを表示'

      select '10:00～12:00 / スクリーン1', from: 'スケジュールを選択'
      click_button '座席を選ぶ'

      click_link 'A-1'

      expect(page).to have_content('A-1')
      expect(page).to have_content('テスト劇場')
      expect(page).to have_content('スクリーン1')
    end
  end
end
