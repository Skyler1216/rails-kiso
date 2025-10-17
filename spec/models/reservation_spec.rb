require 'rails_helper'

RSpec.describe Reservation, type: :model do
  describe 'バリデーション' do
    let(:schedule) { create(:schedule) }
    let(:screen) { schedule.screen }
    let(:sheet) { create(:sheet, screen: screen) }
    let(:reservation) { build(:reservation, schedule: schedule, screen: screen, sheet: sheet) }

    it '有効な属性で作成できること' do
      expect(reservation).to be_valid
    end

    describe 'name' do
      it '必須であること' do
        reservation.name = nil
        expect(reservation).to be_invalid
        expect(reservation.errors.added?(:name, :blank)).to be(true)
      end
    end

    describe 'email' do
      it '必須であること' do
        reservation.email = nil
        expect(reservation).to be_invalid
        expect(reservation.errors.added?(:email, :blank)).to be(true)
      end

      it '有効な形式であること' do
        reservation.email = 'test@example.com'
        expect(reservation).to be_valid
      end

      it '無効な形式は無効であること' do
        reservation.email = 'invalid-email'
        expect(reservation).to be_invalid
        expect(reservation.errors.added?(:email, :invalid, value: 'invalid-email')).to be(true)
      end
    end

    describe 'date' do
      it '必須であること' do
        reservation.date = nil
        expect(reservation).to be_invalid
        expect(reservation.errors.added?(:date, :blank)).to be(true)
      end
    end

    describe 'sheet_id' do
      it '同じスケジュール・日付・スクリーンで一意であること' do
        create(:reservation,
               schedule: schedule,
               screen: screen,
               sheet: sheet,
               date: Date.current)

        reservation.date = Date.current
        expect(reservation).not_to be_valid
        expect(reservation.errors[:sheet_id]).to include('はすでに予約されています')
      end

      it '異なるスケジュールでは同じ座席でも有効であること' do
        other_schedule = create(:schedule,
                                screen: screen,
                                start_time: schedule.start_time + 1.day,
                                end_time: schedule.end_time + 1.day)
        create(:reservation,
               schedule: other_schedule,
               screen: screen,
               sheet: sheet,
               date: Date.current)

        reservation.date = Date.current
        expect(reservation).to be_valid
      end

      it '異なる日付では同じ座席でも有効であること' do
        create(:reservation,
               schedule: schedule,
               screen: screen,
               sheet: sheet,
               date: Date.current)

        reservation.date = Date.current + 1.day
        expect(reservation).to be_valid
      end

      it '異なるスクリーンでは同じ座席でも有効であること' do
        other_screen = create(:screen)
        other_sheet = create(:sheet, screen: other_screen)
        create(:reservation,
               schedule: schedule,
               screen: other_screen,
               sheet: other_sheet,
               date: Date.current)

        reservation.date = Date.current
        expect(reservation).to be_valid
      end
    end
  end

  describe '関連' do
    let(:reservation) { create(:reservation) }

    it 'scheduleとの関連が正しく設定されていること' do
      expect(Reservation.reflect_on_association(:schedule).macro).to eq :belongs_to
    end

    it 'sheetとの関連が正しく設定されていること' do
      expect(Reservation.reflect_on_association(:sheet).macro).to eq :belongs_to
    end

    it 'screenとの関連が正しく設定されていること' do
      expect(Reservation.reflect_on_association(:screen).macro).to eq :belongs_to
    end

    it 'userとの関連が正しく設定されていること（optional: true）' do
      expect(Reservation.reflect_on_association(:user).macro).to eq :belongs_to
      expect(Reservation.reflect_on_association(:user).options[:optional]).to be true
    end
  end

  describe 'email正規表現' do
    let(:schedule) { create(:schedule) }
    let(:screen) { schedule.screen }
    let(:sheet) { create(:sheet, screen: screen) }

    it '有効なメールアドレス形式をテスト' do
      valid_emails = [
        'user@example.com',
        'user.name@example.com',
        'user+tag@example.co.jp',
        'user123@example-domain.com'
      ]

      valid_emails.each do |email|
        reservation = build(:reservation,
                            schedule: schedule,
                            screen: screen,
                            sheet: sheet,
                            email: email)
        expect(reservation).to be_valid, "#{email} should be valid"
      end
    end

    it '無効なメールアドレス形式をテスト' do
      invalid_emails = [
        'invalid-email',
        '@example.com',
        'user@',
        'user@.com',
        'user@example.'
      ]

      invalid_emails.each do |email|
        reservation = build(:reservation,
                            schedule: schedule,
                            screen: screen,
                            sheet: sheet,
                            email: email)
        expect(reservation).to be_invalid, "#{email} should be invalid"
        expect(reservation.errors.added?(:email, :invalid, value: email)).to be(true)
      end
    end
  end
end
