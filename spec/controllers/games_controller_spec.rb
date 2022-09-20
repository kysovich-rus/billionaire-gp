3# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryGirl.create(:user) }
  # админ
  let(:admin) { FactoryGirl.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  # группа тестов для незалогиненного юзера (Анонимус)
  describe '#show' do
    context 'when Guest' do
      before do
        get :show, id: game_w_questions.id
      end
      it 'kicks out from #show' do
        expect(response.status).not_to eq(200) # статус не 200 ОК
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end
    end
    context 'when Logged In' do
      # перед каждым тестом в группе
      before do
        sign_in user # логиним юзера user с помощью спец. Devise метода sign_in
        get :show, id: game_w_questions.id
      end

      # юзер видит свою игру
      it 'gives game to #show' do
        game = assigns(:game) # вытаскиваем из контроллера поле @game
        expect(game.finished?).to be false
        expect(game.user).to eq(user)

        expect(response.status).to eq(200) # должен быть ответ HTTP 200
        expect(response).to render_template('show') # и отрендерить шаблон show
      end
    end
  end

  describe '#create' do
    context 'when Guest' do
      before do
        generate_questions(15)
        post :create
      end
      it 'kicks out from #create' do
        expect(response.status).not_to eq(200) # статус не 200 ОК
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end
    end

    context 'when Logged In' do
      before do
        sign_in user
        generate_questions(15)
        post :create
      end
      it 'creates game' do
        game = assigns(:game)

        expect(game.finished?).to be false
        expect(game.user).to eq(user)

        expect(response).to redirect_to(game_path(game))
        expect(flash[:notice]).to be
      end
    end
  end

  describe '#answer' do
    context 'when Guest' do
      before do
        put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      end
      it 'kicks out from #answer' do
        expect(response.status).not_to eq(200) # статус не 200 ОК
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end
    end

    context 'when Logged In' do
      before do
        sign_in user
        put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      end
      it 'answers correct' do
        game = assigns(:game)

        expect(game.finished?).to be false
        expect(game.current_level).to be > 0

        expect(response).to redirect_to(game_path(game))
        expect(flash.empty?).to be_truthy # удачный ответ не заполняет flash
      end
    end
  end

  describe '#help' do
    context 'when Guest' do
      before do
        put :help, id: game_w_questions.id, help_type: :audience_help
      end
      it 'kicks out from #help' do
        expect(response.status).not_to eq(200) # статус не 200 ОК
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end
    end
    context 'when Logged In' do
      before do
        sign_in user
      end
      context 'before use' do
        it 'does not have this hint' do
          expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
          expect(game_w_questions.audience_help_used).to be false
        end
      end
      context 'after use' do
        before do
          put :help, id: game_w_questions.id, help_type: :audience_help
        end
        it 'uses audience help' do
          game = assigns(:game)

          # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
          expect(game.finished?).to be_falsey
          expect(game.audience_help_used).to be_truthy
          expect(game.current_game_question.help_hash[:audience_help]).to be
          expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
          expect(response).to redirect_to(game_path(game))
        end
      end
    end
  end
end
