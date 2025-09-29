require 'rails_helper'

RSpec.describe 'Movie browsing flow', type: :system do
  before do
    driven_by(:rack_test)
  end

  let!(:movie1) { create(:movie, name: 'アクション映画', is_showing: 1, description: 'スリル満点のアクション') }
  let!(:movie2) { create(:movie, name: 'ロマンス映画', is_showing: 0, description: '感動のロマンス') }
  let!(:movie3) { create(:movie, name: 'コメディ映画', is_showing: 1, description: '笑いのコメディ') }

  describe '映画一覧ページ' do
    it '全映画が表示されること' do
      visit movies_path

      expect(page).to have_content('アクション映画')
      expect(page).to have_content('ロマンス映画')
      expect(page).to have_content('コメディ映画')
    end

    it '上映中のみフィルタリングできること' do
      visit movies_path

      select '上映中', from: '上映ステータス'
      click_button '検索する'

      expect(page).to have_content('アクション映画')
      expect(page).to have_content('コメディ映画')
      expect(page).not_to have_content('ロマンス映画')
    end

    it 'キーワード検索ができること' do
      visit movies_path

      fill_in 'キーワード検索', with: 'アクション'
      click_button '検索する'

      expect(page).to have_content('アクション映画')
      expect(page).not_to have_content('ロマンス映画')
      expect(page).not_to have_content('コメディ映画')
    end

    it '説明文での検索ができること' do
      visit movies_path

      fill_in 'キーワード検索', with: '感動'
      click_button '検索する'

      expect(page).to have_content('ロマンス映画')
      expect(page).not_to have_content('アクション映画')
      expect(page).not_to have_content('コメディ映画')
    end
  end

  describe '映画詳細ページ' do
    let!(:theater) { create(:theater, name: 'テスト劇場') }
    let!(:screen) { create(:screen, theater: theater, name: 'スクリーン1') }
    let(:future_start_time) { 5.days.from_now.change(hour: 10, min: 0) }
    let!(:schedule) { create(:schedule, movie: movie1, screen: screen, start_time: future_start_time) }

    it '映画詳細が表示されること' do
      visit movie_path(movie1)

      expect(page).to have_content('アクション映画')
      expect(page).to have_content('スリル満点のアクション')
    end

    it '上映劇場が表示されること' do
      visit movie_path(movie1)

      expect(page).to have_content('テスト劇場')
    end

    it '劇場選択ができること' do
      visit movie_path(movie1)

      expect(page).to have_select('劇場を選択')
    end

    it '日付選択ができること' do
      visit movie_path(movie1)

      expect(page).to have_select('日付を選択')
    end
  end

  describe 'ルートページ' do
    it '映画一覧が表示されること' do
      visit root_path

      expect(page).to have_content('アクション映画')
      expect(page).to have_content('ロマンス映画')
      expect(page).to have_content('コメディ映画')
    end
  end
end
