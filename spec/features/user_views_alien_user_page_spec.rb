require 'rails_helper'

RSpec.feature 'User views alien user page', type: :feature do
  let(:profile_owner) { FactoryGirl.create(:user, name: 'Alpha Bot') }
  let(:profile_visitor) { FactoryGirl.create(:user, name: 'Beta Bot') }

  let!(:games) do
    [
      FactoryGirl.create(:game,
                        user: profile_owner,
                        id: 101,
                        created_at: Time.parse('2020.10.01, 10:00'),
                        current_level: 10,
                        prize: 1000),

      FactoryGirl.create(:game,
                        user: profile_owner,
                        id: 102,
                        created_at: Time.parse('2020.10.01, 13:00'),
                        finished_at: Time.parse('2020.10.01, 14:00'),
                        is_failed: true)
    ]
  end

  before do
    login_as profile_visitor
  end

  feature 'app successfully' do
    before do
      visit '/users/1'
    end

    it 'displays profile owner name' do
      expect(page).to have_content 'Alpha Bot'
    end

    it 'ignores link to edit user registration page' do
      expect(page).not_to have_content 'Сменить имя и пароль'
    end

    it 'displays game_id' do
      expect(page).to have_content '101'
      expect(page).to have_content '102'
    end

    it 'displays dates of game start' do
      expect(page).to have_content '1 окт., 10:00'
      expect(page).to have_content '1 окт., 13:00'
    end

    it 'displays number of current question' do
      expect(page).to have_content '10'
    end

    it 'displays prize' do
      expect(page).to have_content '1 000 ₽'
    end

    it 'should show statuses of games' do
      expect(page).to have_content 'в процессе'
      expect(page).to have_content 'время'
    end
  end
end
