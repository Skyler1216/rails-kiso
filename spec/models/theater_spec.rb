require 'rails_helper'

RSpec.describe Theater, type: :model do
  describe 'validations' do
    it 'is valid with a factory' do
      expect(build(:theater)).to be_valid
    end

    it 'is invalid without a name' do
      theater = build(:theater, name: nil)

      expect(theater).not_to be_valid
      expect(theater.errors[:name]).to include("can't be blank")
    end

    it 'is invalid without an address' do
      theater = build(:theater, address: nil)

      expect(theater).not_to be_valid
      expect(theater.errors[:address]).to include("can't be blank")
    end

    it 'does not allow duplicate theater names (case insensitive)' do
      create(:theater, name: 'Test Theater')
      duplicate = build(:theater, name: 'test theater')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')
    end

    it 'does not allow duplicate screen names within the same theater (case-insensitive)' do
      theater = build(:theater)
      theater.screens.build(name: 'Screen A')
      theater.screens.build(name: 'screen a')

      expect(theater).not_to be_valid
      expect(theater.screens.first.errors[:name]).to include('は同じ劇場内で一意になるよう設定してください')
      expect(theater.screens.second.errors[:name]).to include('は同じ劇場内で一意になるよう設定してください')
    end
  end

  describe 'associations' do
    it 'removes associated screens when destroyed' do
      theater = create(:theater)
      create(:screen, theater: theater)

      expect { theater.destroy }.to change { Screen.where(theater_id: theater.id).count }.from(1).to(0)
    end
  end
end
