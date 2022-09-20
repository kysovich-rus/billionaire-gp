require 'rails_helper'

RSpec.describe 'users/show', type: :view do
  let(:user) { FactoryGirl.create(:user, name: 'my_username') }
  before do
    assign(:user, user)
    assign(:games, [
      FactoryGirl.build_stubbed(:game)
    ])
    stub_template 'users/_game.html.erb' => 'This is user game, it has to be'
  end

  context 'current user is signed in' do
    before do
      sign_in user
      render
    end

    it 'displays game partial' do
      expect(rendered).to match 'This is user game, it has to be'
    end

    it 'displays current user name' do
      expect(rendered).to match 'my_username'
    end

    it 'displays edit_user link' do
      expect(rendered).to match 'Сменить имя и пароль'
    end
  end

  context 'any other user is signed in' do
    let(:user1) { FactoryGirl.create(:user, name: 'my_rival') }
    before do
      sign_in user1
      render
    end

    it 'displays game partial' do
      expect(rendered).to match 'This is user game, it has to be'
    end

    it 'displays profile user name' do
      expect(rendered).to match 'my_username'
    end

    it 'ignores current user name' do
      expect(rendered).not_to match 'my_rival'
    end

    it 'ignores edit_user link' do
      expect(rendered).not_to match 'Сменить имя и пароль'
    end
  end
end