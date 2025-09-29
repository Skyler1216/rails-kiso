require 'rails_helper'

RSpec.describe Theater, type: :model do
  describe 'バリデーション' do
    let(:theater) { build(:theater) }

    it '有効な属性で作成できること' do
      expect(theater).to be_valid
    end

    describe 'name' do
      it '必須であること' do
        theater.name = nil
        expect(theater).not_to be_valid
        expect(theater.errors[:name]).to include("can't be blank")
      end

      it '一意であること（大文字小文字を区別しない）' do
        create(:theater, name: 'TOHOシネマ')
        theater.name = 'tohoシネマ'
        expect(theater).not_to be_valid
        expect(theater.errors[:name]).to include('has already been taken')
      end
    end

    describe 'address' do
      it '必須であること' do
        theater.address = nil
        expect(theater).not_to be_valid
        expect(theater.errors[:address]).to include("can't be blank")
      end

      it '空文字は無効であること' do
        theater.address = ''
        expect(theater).not_to be_valid
        expect(theater.errors[:address]).to include("can't be blank")
      end
    end
  end

  describe '関連' do
    it 'screensとの関連が正しく設定されていること' do
      expect(Theater.reflect_on_association(:screens).macro).to eq :has_many
    end

    it 'dependent: :destroyが設定されていること' do
      theater = create(:theater)
      screen = create(:screen, theater: theater)
      
      expect { theater.destroy }.to change { Screen.count }.by(-1)
    end

    it 'accepts_nested_attributes_for :screensが設定されていること' do
      expect(Theater._nested_attributes_options).to have_key(:screens)
    end
  end

  describe 'ネストされたスクリーンのバリデーション' do
    let(:theater) { build(:theater) }

    it '同じ劇場内でスクリーン名が重複しないこと' do
      theater.screens.build(name: 'スクリーン1')
      theater.screens.build(name: 'スクリーン1')
      
      expect(theater).not_to be_valid
      expect(theater.screens.first.errors[:name]).to include('は同じ劇場内で一意になるよう設定してください')
      expect(theater.screens.last.errors[:name]).to include('は同じ劇場内で一意になるよう設定してください')
    end

    it '大文字小文字を区別せずに重複チェックすること' do
      theater.screens.build(name: 'スクリーン1')
      theater.screens.build(name: 'スクリーン１')
      
      expect(theater).not_to be_valid
    end

    it '空白を除去して重複チェックすること' do
      theater.screens.build(name: 'スクリーン1')
      theater.screens.build(name: ' スクリーン1 ')
      
      expect(theater).not_to be_valid
    end

    it '削除予定のスクリーンは重複チェックから除外されること' do
      theater.screens.build(name: 'スクリーン1')
      screen2 = theater.screens.build(name: 'スクリーン1')
      screen2.mark_for_destruction
      
      expect(theater).to be_valid
    end

    it '空のスクリーン名は重複チェックから除外されること' do
      theater.screens.build(name: 'スクリーン1')
      theater.screens.build(name: '')
      
      expect(theater).to be_valid
    end
  end
end