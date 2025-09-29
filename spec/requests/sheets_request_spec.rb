require 'rails_helper'

RSpec.describe 'Sheets', type: :request do
  let!(:screen) { create(:screen, theater: create(:theater, name: 'シネマA'), name: 'スクリーン1') }

  describe 'GET /sheets' do
    it '座席一覧ページが表示されること' do
      get sheets_path
      expect(response).to have_http_status(200)
    end

    it '劇場名と座席ラベルが表示されること' do
      get sheets_path
      expect(response.body).to include('シネマA')
      expect(response.body).to include('スクリーン1')
      expect(response.body).to include('A-1')
      expect(response.body).to include('B-1')
    end
  end
end
