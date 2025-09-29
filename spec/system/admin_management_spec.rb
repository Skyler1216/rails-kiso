require 'rails_helper'

RSpec.describe 'Admin management flow', type: :system do
  before do
    driven_by(:rack_test)
  end

  let!(:admin_user) { create(:user, :admin, email: 'admin@example.com') }
  let!(:regular_user) { create(:user, email: 'user@example.com') }

  describe '管理者認証' do
    it '管理者でログインすると管理画面にアクセスできること' do
      sign_in admin_user
      visit admin_root_path

      expect(page).to have_current_path(admin_root_path)
      expect(page).to have_content('Admin CONTROL CENTER')
      expect(page).to have_content('ダッシュボード')
    end

    it '一般ユーザーでは管理画面にアクセスできないこと' do
      sign_in regular_user
      visit admin_root_path

      expect(page).to have_content('管理者権限が必要です')
      expect(page).to have_current_path(root_path)
    end

    it 'ログインしていない場合は管理画面にアクセスできないこと' do
      visit admin_root_path

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content('ログイン')
    end
  end

  describe '映画管理' do
    before do
      sign_in admin_user
    end

    it '映画一覧が表示されること' do
      movie = create(:movie, name: 'テスト映画')
      visit admin_movies_path

      expect(page).to have_content('テスト映画')
    end

    it '新しい映画を作成できること' do
      visit new_admin_movie_path

      fill_in 'タイトル', with: '新作映画'
      fill_in '公開年', with: '2024'
      fill_in '概要', with: '素晴らしい映画です'
      fill_in '画像URL', with: 'https://example.com/image.jpg'
      check '上映中'
      fill_in '上映時間（分）', with: '120'

      expect {
        click_button '登録する'
      }.to change(Movie, :count).by(1)

      expect(page).to have_content('映画を登録しました')
    end

    it '映画を編集できること' do
      movie = create(:movie, name: '編集前の映画')
      visit admin_movie_path(movie)

      fill_in 'タイトル', with: '編集後の映画'
      click_button '更新する'

      expect(page).to have_content('映画を更新しました')
      movie.reload
      expect(movie.name).to eq('編集後の映画')
    end

    it '映画を削除できること' do
      movie = create(:movie, name: '削除対象の映画')
      visit admin_movie_path(movie)

      expect {
        click_button '削除する'
      }.to change(Movie, :count).by(-1)

      expect(page).to have_content('映画を削除しました')
    end
  end

  describe '劇場管理' do
    before do
      sign_in admin_user
    end

    it '劇場一覧が表示されること' do
      theater = create(:theater, name: 'テスト劇場')
      visit admin_theaters_path

      expect(page).to have_content('テスト劇場')
    end

    it '新しい劇場を作成できること' do
      visit new_admin_theater_path

      fill_in '劇場名', with: '新劇場'
      fill_in '住所', with: '東京都新宿区1-1-1'
      fill_in '電話番号', with: '03-1234-5678'

      expect {
        click_button '登録する'
      }.to change(Theater, :count).by(1)

      expect(page).to have_content('劇場を登録しました')
    end
  end

  describe 'スケジュール管理' do
    before do
      sign_in admin_user
    end

    it 'スケジュール一覧が表示されること' do
      movie = create(:movie)
      theater = create(:theater)
      screen = create(:screen, theater: theater)
      schedule = create(:schedule, movie: movie, screen: screen)
      
      visit admin_schedules_path

      expect(page).to have_content(movie.name)
      expect(page).to have_content(theater.name)
    end

    it '新しいスケジュールを作成できること' do
      movie = create(:movie)
      theater = create(:theater)
      screen = create(:screen, theater: theater)
      
      visit new_admin_schedule_path

      select "#{movie.id}: #{movie.name}", from: '対象作品'
      select "#{theater.name} / #{screen.name}", from: 'スクリーン'
      fill_in '開始時刻', with: '2025-09-22T10:00'
      fill_in '終了時刻', with: '2025-09-22T12:00'

      expect {
        click_button '登録する'
      }.to change(Schedule, :count).by(1)

      expect(page).to have_content('スケジュールを作成しました')
    end
  end

  describe '予約管理' do
    before do
      sign_in admin_user
    end

    it '予約一覧が表示されること' do
      user = create(:user)
      movie = create(:movie)
      theater = create(:theater)
      screen = create(:screen, theater: theater)
      schedule = create(:schedule, movie: movie, screen: screen)
      sheet = create(:sheet, screen: screen)
      reservation = create(:reservation, user: user, schedule: schedule, sheet: sheet)
      
      visit admin_reservations_path

      expect(page).to have_content(user.name)
      expect(page).to have_content(movie.name)
    end
  end
end
