require 'rails_helper'

RSpec.describe 'Sheets', type: :request do
  let!(:screen) { create(:screen) }
  let!(:sheet1) { create(:sheet, screen: screen, row: 'A', column: 1) }
  let!(:sheet2) { create(:sheet, screen: screen, row: 'A', column: 2) }
  let!(:sheet3) { create(:sheet, screen: screen, row: 'B', column: 1) }

  describe 'GET /sheets' do
    it '座席一覧ページが表示されること' do
      get sheets_path
      expect(response).to have_http_status(200)
    end

    it '座席がrowでグループ化されて表示されること' do
      get sheets_path
      expect(response.body).to include('A')
      expect(response.body).to include('B')
    end
  end
end
