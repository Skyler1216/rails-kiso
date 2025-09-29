require 'rails_helper'

RSpec.describe SheetsController, type: :controller do
  render_views

  describe 'GET #index' do
    let!(:screen1) { create(:screen, theater: create(:theater, name: '劇場A'), name: 'スクリーンA') }
    let!(:screen2) { create(:screen, theater: create(:theater, name: '劇場B'), name: 'スクリーンB') }

    it '200を返すこと' do
      get :index
      expect(response).to have_http_status(200)
    end

    it '劇場ごとのスクリーンと座席を取得すること' do
      get :index
      theaters = assigns(:theaters)
      expect(theaters.map(&:id)).to contain_exactly(screen1.theater_id, screen2.theater_id)
      expected_screen_count = theaters.sum { |theater| theater.screens.size }
      expected_seat_count = theaters.sum { |theater| theater.screens.sum { |screen| screen.sheets.size } }
      expect(assigns(:total_screens)).to eq(expected_screen_count)
      expect(assigns(:total_seats)).to eq(expected_seat_count)
      expect(assigns(:sample_layout_rows)).to eq([['A', [1, 2, 3, 4, 5]],
                                                 ['B', [1, 2, 3, 4, 5]],
                                                 ['C', [1, 2, 3, 4, 5]]])
    end

    it 'HTMLを返すこと' do
      get :index
      expect(response.body).to include(screen1.theater.name)
      expect(response.body).to include(screen1.name)
      expect(response.body).to include('A-1')
    end
  end
end
