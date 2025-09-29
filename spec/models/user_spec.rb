require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'バリデーション' do
    let(:user) { build(:user) }

    it '有効な属性で作成できること' do
      expect(user).to be_valid
    end

    describe 'name' do
      it '必須であること' do
        user.name = nil
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("can't be blank")
      end
    end

    describe 'email' do
      it '必須であること' do
        user.email = nil
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("can't be blank")
      end

      it '一意であること' do
        create(:user, email: 'test@example.com')
        user.email = 'test@example.com'
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('has already been taken')
      end
    end

    describe 'password' do
      it '必須であること' do
        user.password = nil
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("can't be blank")
      end

      it 'password_confirmationが必須であること' do
        user.password_confirmation = nil
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).to include("can't be blank")
      end

      it 'passwordとpassword_confirmationが一致すること' do
        user.password = 'password123'
        user.password_confirmation = 'different_password'
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).to include("doesn't match Password")
      end
    end

    describe 'admin' do
      it 'trueまたはfalseであること' do
        user.admin = true
        expect(user).to be_valid

        user.admin = false
        expect(user).to be_valid

        user.admin = nil
        expect(user).not_to be_valid
        expect(user.errors[:admin]).to include('is not included in the list')
      end
    end
  end

  describe '関連' do
    let(:user) { create(:user) }

    it 'reservationsとの関連が正しく設定されていること' do
      expect(User.reflect_on_association(:reservations).macro).to eq :has_many
    end
  end

  describe 'Devise設定' do
    it 'database_authenticatableが有効であること' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'registerableが有効であること' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'recoverableが有効であること' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'rememberableが有効であること' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'validatableが有効であること' do
      expect(User.devise_modules).to include(:validatable)
    end
  end

  describe 'インスタンスメソッド' do
    describe '#admin?' do
      it 'adminがtrueの場合、trueを返すこと' do
        user = build(:user, admin: true)
        expect(user.admin?).to be true
      end

      it 'adminがfalseの場合、falseを返すこと' do
        user = build(:user, admin: false)
        expect(user.admin?).to be false
      end
    end

    describe '#regular_user?' do
      it 'adminがfalseの場合、trueを返すこと' do
        user = build(:user, admin: false)
        expect(user.regular_user?).to be true
      end

      it 'adminがtrueの場合、falseを返すこと' do
        user = build(:user, admin: true)
        expect(user.regular_user?).to be false
      end
    end
  end

  describe 'FactoryBot traits' do
    it 'adminトレイトが正しく動作すること' do
      admin_user = create(:user, :admin)
      expect(admin_user.admin).to be true
      expect(admin_user.admin?).to be true
      expect(admin_user.regular_user?).to be false
    end
  end
end