require 'rails_helper'

RSpec.describe 'User authentication flow', type: :system do
  before do
    driven_by(:rack_test)
  end

  let!(:user) { create(:user, email: 'test@example.com', password: 'password123') }

  describe 'ユーザー登録' do
    it '新規ユーザーが登録できること' do
      visit new_user_registration_path

      fill_in '名前', with: '新規ユーザー'
      fill_in 'メールアドレス', with: 'newuser@example.com'
      fill_in 'パスワード', with: 'password123'
      fill_in 'パスワード（確認）', with: 'password123'

      expect {
        click_button 'アカウント登録'
      }.to change(User, :count).by(1)

      expect(page).to have_content('アカウント登録が完了しました')
    end

    it '無効な情報では登録できないこと' do
      visit new_user_registration_path

      fill_in '名前', with: ''
      fill_in 'メールアドレス', with: 'invalid-email'
      fill_in 'パスワード', with: '123'
      fill_in 'パスワード（確認）', with: '456'

      expect {
        click_button 'アカウント登録'
      }.not_to change(User, :count)

      expect(page).to have_content('エラーが発生しました')
    end
  end

  describe 'ログイン' do
    it '正しい情報でログインできること' do
      visit new_user_session_path

      fill_in 'メールアドレス', with: user.email
      fill_in 'パスワード', with: 'password123'
      click_button 'ログインする'

      expect(page).to have_content('ログインしました')
    end

    it '間違った情報ではログインできないこと' do
      visit new_user_session_path

      fill_in 'メールアドレス', with: user.email
      fill_in 'パスワード', with: 'wrongpassword'
      click_button 'ログインする'

      expect(page).to have_content('メールアドレスまたはパスワードが違います')
    end
  end

  describe 'ログアウト' do
    before do
      sign_in user
    end

    it 'ログアウトできること' do
      visit root_path
      click_link 'ログアウト'

      expect(page).to have_content('ログアウトしました')
    end
  end

  describe '認証が必要なページ' do
    let!(:theater) { create(:theater) }
    let!(:screen) { create(:screen, theater: theater) }
    let!(:movie) { create(:movie) }
    let!(:schedule) { create(:schedule, movie: movie, screen: screen) }
    let!(:sheet) { create(:sheet, screen: screen) }

    it 'ログインしていない場合は予約ページにアクセスできないこと' do
      visit new_movie_schedule_reservation_path(movie, schedule, sheet_id: sheet.id, date: '2025-09-22')

      expect(page).to have_content('ログインしてください')
    end

    it 'ログイン後は予約ページにアクセスできること' do
      sign_in user
      visit new_movie_schedule_reservation_path(movie, schedule, sheet_id: sheet.id, date: '2025-09-22')

      expect(page).to have_content('予約情報を入力してください')
    end
  end
end
