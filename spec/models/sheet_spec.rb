require 'rails_helper'

RSpec.describe Sheet, type: :model do
  describe 'バリデーション' do
    let(:screen) { create(:screen) }
    let(:sheet) { build(:sheet, screen: screen) }

    it '有効な属性で作成できること' do
      expect(sheet).to be_valid
    end

    describe 'screen' do
      it '必須であること' do
        sheet.screen = nil
        expect(sheet).to be_invalid
        expect(sheet.errors[:screen]).to include(a_string_including('スクリーン'))
      end
    end
  end

  describe '関連' do
    let(:sheet) { create(:sheet) }

    it 'screenとの関連が正しく設定されていること' do
      expect(Sheet.reflect_on_association(:screen).macro).to eq :belongs_to
    end
  end

  describe 'FactoryBot設定' do
    it 'rowが正しく生成されること' do
      sheet = create(:sheet)
      expect(sheet.row).to match(/[A-Z]/)
    end

    it 'columnが正しく生成されること' do
      sheet = create(:sheet)
      expect(sheet.column).to be_between(1, 10)
    end

    it '複数のシートで異なるrow/columnが生成されること' do
      screen = create(:screen)
      sheet1 = create(:sheet, screen: screen)
      sheet2 = create(:sheet, screen: screen)

      expect(sheet1.row).not_to eq(sheet2.row) if sheet1.column == sheet2.column
      expect(sheet1.column).not_to eq(sheet2.column) if sheet1.row == sheet2.row
    end
  end
end
