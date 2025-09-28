require 'rails_helper'

RSpec.describe 'Admin::Theaters', type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
  end

  describe 'POST /admin/theaters' do
    it 'creates a theater with the given screens' do
      expect do
        post admin_theaters_path, params: {
          theater: {
            name: 'テスト劇場',
            address: '東京都千代田区1-1-1',
            phone: '03-0000-0000',
            is_active: '1',
            screens_attributes: {
              '0' => { name: 'スクリーンA' },
              '1' => { name: 'スクリーンB' }
            }
          }
        }
      end.to change(Theater, :count).by(1).and change(Screen, :count).by(2)

      theater = Theater.order(:created_at).last
      expect(theater.screens.pluck(:name)).to match_array(%w[スクリーンA スクリーンB])
    end
  end

  describe 'PATCH /admin/theaters/:id' do
    it 'updates existing screens and handles deletions and additions in one request' do
      theater = create(:theater)
      screen_a = create(:screen, theater: theater, name: 'スクリーンA')
      screen_b = create(:screen, theater: theater, name: 'スクリーンB')

      patch admin_theater_path(theater), params: {
        theater: {
          name: theater.name,
          address: theater.address,
          phone: theater.phone,
          is_active: theater.is_active,
          screens_attributes: {
            '0' => { id: screen_a.id, name: 'スクリーンA・改' },
            '1' => { id: screen_b.id, _destroy: '1' },
            '2' => { name: 'スクリーンC' }
          }
        }
      }

      expect(response).to redirect_to(admin_theaters_path)

      theater.reload
      expect(theater.screens.pluck(:name)).to match_array(['スクリーンA・改', 'スクリーンC'])
    end
  end
end
