require 'rails_helper'

RSpec.describe Screen, type: :model do
  describe 'バリデーション' do
    let(:theater) { create(:theater) }
    let(:screen) { build(:screen, theater: theater) }

    it '有効な属性で作成できること' do
      expect(screen).to be_valid
    end

    describe 'name' do
      it '必須であること' do
        screen.name = nil
        expect(screen).to be_invalid
        expect(screen.errors.added?(:name, :blank)).to be(true)
      end

      it '同じ劇場内で一意であること' do
        create(:screen, theater: theater, name: 'スクリーン1')
        screen.name = 'スクリーン1'
        expect(screen).not_to be_valid
        expect(screen.errors[:name]).to include('は同じ劇場内で一意になるよう設定してください')
      end

      it '異なる劇場では同じ名前でも有効であること' do
        other_theater = create(:theater)
        create(:screen, theater: other_theater, name: 'スクリーン1')
        screen.name = 'スクリーン1'
        expect(screen).to be_valid
      end

      it '大文字小文字を区別しないこと' do
        create(:screen, theater: theater, name: 'スクリーン1')
        screen.name = 'スクリーン１'
        expect(screen).not_to be_valid
      end
    end
  end

  describe '関連' do
    let(:theater) { create(:theater) }

    it 'theaterとの関連が正しく設定されていること' do
      expect(Screen.reflect_on_association(:theater).macro).to eq :belongs_to
    end

    it 'sheetsとの関連が正しく設定されていること' do
      expect(Screen.reflect_on_association(:sheets).macro).to eq :has_many
    end

    it 'schedulesとの関連が正しく設定されていること' do
      expect(Screen.reflect_on_association(:schedules).macro).to eq :has_many
    end

    it 'dependent: :destroyが設定されていること（sheets）' do
      screen = create(:screen, theater: theater)
      seat_count = screen.sheets.count

      expect { screen.destroy }.to change(Sheet, :count).by(-seat_count)
    end

    it 'dependent: :destroyが設定されていること（schedules）' do
      screen = create(:screen, theater: theater)
      create(:schedule, screen: screen)

      expect { screen.destroy }.to change { Schedule.count }.by(-1)
    end

    it '作成時に標準座席が生成されること' do
      screen = create(:screen, theater: theater)
      expect(screen.sheets.count).to eq(15)
      expect(screen.sheets.pluck(:row).uniq.sort).to eq(%w[A B C])
      expect(screen.sheets.pluck(:column).uniq.sort).to eq((1..5).to_a)
    end
  end
end
