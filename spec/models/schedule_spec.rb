require 'rails_helper'

RSpec.describe Schedule, type: :model do
  describe 'バリデーション' do
    let(:movie) { create(:movie, running_minutes: 120) }
    let(:screen) { create(:screen) }
    let(:schedule) { build(:schedule, movie: movie, screen: screen) }

    it '有効な属性で作成できること' do
      expect(schedule).to be_valid
    end

    describe 'start_time' do
      it '必須であること' do
        schedule.start_time = nil
        expect(schedule).not_to be_valid
        expect(schedule.errors[:start_time]).to include("can't be blank")
      end
    end

    describe 'end_time' do
      it '必須であること' do
        schedule.end_time = nil
        expect(schedule).not_to be_valid
        expect(schedule.errors[:end_time]).to include("can't be blank")
      end

      it '開始時刻より後の時刻であること' do
        schedule.start_time = Time.zone.parse('2025-09-22 10:00:00')
        schedule.end_time = Time.zone.parse('2025-09-22 09:00:00')
        expect(schedule).not_to be_valid
        expect(schedule.errors[:end_time]).to include('は開始時刻より後の時刻を指定してください')
      end
    end

    describe '重複チェック' do
      let!(:existing_schedule) do
        create(:schedule, 
               screen: screen,
               start_time: Time.zone.parse('2025-09-22 10:00:00'),
               end_time: Time.zone.parse('2025-09-22 12:00:00'))
      end

      it '同じスクリーンで重複するスケジュールは無効であること' do
        schedule.start_time = Time.zone.parse('2025-09-22 11:00:00')
        schedule.end_time = Time.zone.parse('2025-09-22 13:00:00')
        expect(schedule).not_to be_valid
        expect(schedule.errors[:base]).to include('同じスクリーンで日程が重複しています')
      end

      it '重複しないスケジュールは有効であること' do
        schedule.start_time = Time.zone.parse('2025-09-22 13:00:00')
        schedule.end_time = Time.zone.parse('2025-09-22 15:00:00')
        expect(schedule).to be_valid
      end

      it '異なるスクリーンでは重複しても有効であること' do
        other_screen = create(:screen)
        schedule.screen = other_screen
        schedule.start_time = Time.zone.parse('2025-09-22 11:00:00')
        schedule.end_time = Time.zone.parse('2025-09-22 13:00:00')
        expect(schedule).to be_valid
      end
    end
  end

  describe '関連' do
    let(:schedule) { create(:schedule) }

    it 'movieとの関連が正しく設定されていること' do
      expect(Schedule.reflect_on_association(:movie).macro).to eq :belongs_to
    end

    it 'screenとの関連が正しく設定されていること' do
      expect(Schedule.reflect_on_association(:screen).macro).to eq :belongs_to
    end

    it 'reservationsとの関連が正しく設定されていること' do
      expect(Schedule.reflect_on_association(:reservations).macro).to eq :has_many
    end

    it 'dependent: :destroyが設定されていること' do
      create(:reservation, schedule: schedule)
      
      expect { schedule.destroy }.to change { Reservation.count }.by(-1)
    end
  end

  describe 'コールバック' do
    let(:movie) { create(:movie, running_minutes: 120) }
    let(:screen) { create(:screen) }

    describe 'populate_end_time_from_movie' do
      it '映画の上映時間から終了時刻を自動設定すること' do
        schedule = build(:schedule, 
                        movie: movie, 
                        screen: screen,
                        start_time: Time.zone.parse('2025-09-22 10:00:00'),
                        end_time: nil)
        
        schedule.valid?
        expect(schedule.end_time).to eq(Time.zone.parse('2025-09-22 12:00:00'))
      end

      it '開始時刻が変更された場合、終了時刻も再計算されること' do
        schedule = create(:schedule, 
                         movie: movie, 
                         screen: screen,
                         start_time: Time.zone.parse('2025-09-22 10:00:00'))
        
        schedule.start_time = Time.zone.parse('2025-09-22 14:00:00')
        schedule.valid?
        expect(schedule.end_time).to eq(Time.zone.parse('2025-09-22 16:00:00'))
      end

      it '手動で終了時刻が設定されている場合は自動設定されないこと' do
        schedule = build(:schedule, 
                        movie: movie, 
                        screen: screen,
                        start_time: Time.zone.parse('2025-09-22 10:00:00'),
                        end_time: Time.zone.parse('2025-09-22 11:30:00'))
        
        schedule.valid?
        expect(schedule.end_time).to eq(Time.zone.parse('2025-09-22 11:30:00'))
      end
    end

    describe 'sync_reservation_metadata!' do
      let(:schedule) { create(:schedule, movie: movie, screen: screen) }
      let!(:reservation) { create(:reservation, schedule: schedule) }

      it '開始時刻が変更された場合、予約の日付も更新されること' do
        new_start_time = Time.zone.parse('2025-09-23 10:00:00')
        schedule.update!(start_time: new_start_time)
        
        reservation.reload
        expect(reservation.date).to eq(new_start_time.to_date)
      end

      it 'スクリーンが変更された場合、予約のスクリーンIDも更新されること' do
        new_screen = create(:screen)
        schedule.update!(screen: new_screen)
        
        reservation.reload
        expect(reservation.screen_id).to eq(new_screen.id)
      end
    end
  end
end