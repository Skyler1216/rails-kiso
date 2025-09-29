require 'rails_helper'

RSpec.describe SheetsController, type: :controller do
  describe 'GET #index' do
    let!(:screen1) { create(:screen) }
    let!(:screen2) { create(:screen) }
    let!(:sheet_a1) { create(:sheet, screen: screen1, row: 'A', column: 1) }
    let!(:sheet_a2) { create(:sheet, screen: screen1, row: 'A', column: 2) }
    let!(:sheet_b1) { create(:sheet, screen: screen2, row: 'B', column: 1) }

    it '200を返すこと' do
      get :index
      expect(response).to have_http_status(200)
    end

    it '座席をrowでグループ化して表示すること' do
      get :index
      expect(assigns(:sheets)).to be_a(Hash)
      expect(assigns(:sheets)['A']).to include(sheet_a1, sheet_a2)
      expect(assigns(:sheets)['B']).to include(sheet_b1)
    end

    it 'HTMLを返すこと' do
      get :index
      expect(response.body).to include('<!DOCTYPE html>')
    end
  end
end
