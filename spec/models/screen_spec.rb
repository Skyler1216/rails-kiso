require 'rails_helper'

RSpec.describe Screen, type: :model do
  describe 'validations' do
    it 'is valid with a factory' do
      expect(build(:screen)).to be_valid
    end

    it 'is invalid without a theater' do
      screen = build(:screen, theater: nil)

      expect(screen).not_to be_valid
      expect(screen.errors[:theater]).to include('must exist')
    end

    it 'is invalid without a name' do
      screen = build(:screen, name: nil)

      expect(screen).not_to be_valid
      expect(screen.errors[:name]).to include("can't be blank")
    end
  end

  describe 'associations' do
    it 'removes associated sheets when destroyed' do
      screen = create(:screen)
      create(:sheet, screen: screen)

      expect { screen.destroy }.to change { Sheet.where(screen_id: screen.id).count }.from(1).to(0)
    end

    it 'removes associated schedules when destroyed' do
      screen = create(:screen)
      create(:schedule, screen: screen)

      expect { screen.destroy }.to change { Schedule.where(screen_id: screen.id).count }.from(1).to(0)
    end
  end
end
