require 'rails_helper'

RSpec.describe Admin::SchedulesController, type: :controller do
  render_views

  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
  end

  describe 'GET #show' do
    it 'スケジュール詳細ページを表示できること' do
      schedule = create(:schedule)

      get :show, params: { id: schedule.id }

      expect(response).to have_http_status(:ok)
      expect(assigns(:schedule)).to eq(schedule)
      expect(response.body).to include("##{schedule.id}")
    end
  end

  describe 'PATCH #update' do
    it '渡された開始時刻でスケジュールが更新されること' do
      schedule = create(:schedule)
      new_time = Time.zone.parse('2000-01-01 10:27:06 UTC')

      patch :update, params: { id: schedule.id, schedule: { start_time: new_time } }

      expect(schedule.reload.start_time).to eq(new_time)
    end
  end

  describe 'DELETE #destroy' do
    it '指定したスケジュールを削除できること' do
      schedule = create(:schedule)

      expect do
        delete :destroy, params: { id: schedule.id }
      end.to change(Schedule, :count).by(-1)
    end
  end
end
