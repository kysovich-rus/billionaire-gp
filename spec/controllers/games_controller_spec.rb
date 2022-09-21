# (c) goodprogrammer.ru

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

  let (:game) { assigns(:game) }

  # группа тестов для незалогиненного юзера (Анонимус)
  describe '#show' do
    context 'when Guest' do
      before do
        get :show, id: game_w_questions.id
      end

      it 'returns no positive response' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'returns alert flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when Logged In user' do
      before do
        sign_in user # логиним юзера user с помощью спец. Devise метода sign_in
      end

      context 'when tries to access own game' do
        # юзер видит свою игру
        it 'gives game to #show' do
          get :show, id: game_w_questions.id

          expect(game.finished?).to be false
          expect(game.user).to eq(user)

          expect(response.status).to eq(200) # должен быть ответ HTTP 200
          expect(response).to render_template('show') # и отрендерить шаблон show
        end
      end

      context 'when tries to access someone else game' do
        let (:alien_game) { FactoryGirl.create(:game_with_questions) }
        it 'refuses to show game' do
          get :show, id: alien_game.id

          expect(response.status).not_to eq(200) # должен быть ответ HTTP 200
          expect(response).to redirect_to(root_path) # и отрендерить шаблон show
          expect(flash[:alert]).to be
        end
      end
    end
  end

  describe '#create' do
    context 'when Guest' do
      before do
        generate_questions(15)
        post :create, id: game_w_questions.id
      end
      it 'returns no positive response' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'returns alert flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when Logged In' do
      before do
        sign_in user
      end

      context 'creates new game' do
        it 'creates game' do
          generate_questions(15)
          post :create

          expect(game.finished?).to be false
          expect(game.user).to eq(user)

          expect(response).to redirect_to(game_path(game))
          expect(flash[:notice]).to be
        end
      end

      context 'creates new game not finishing last one' do
        it 'detects a game in progress' do
          expect(game_w_questions.finished?).to be false
        end

        setup do
          # задаем url старой игры
          @request.env['HTTP_REFERER'] = 'http://test.host/games/1'
          post :create
        end

        it 'refuses to create new game' do
          expect { post :create }.to change(Game, :count).by(0)
          expect(game).to be nil
        end

        it 'redirects to present game' do
          expect(response).to redirect_to(game_path(game_w_questions))
          expect(flash[:alert]).to be
        end
      end
    end
  end

  describe '#answer' do
    context 'when Guest' do
      before do
        put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      end

      it 'returns no positive response' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'returns alert flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when Logged In' do
      before do
        sign_in user
      end

      context 'answers correct' do
        it 'continues the game' do
          put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key

          expect(game.finished?).to be false
          expect(game.current_level).to be > 0

          expect(response).to redirect_to(game_path(game))
          expect(flash.empty?).to be true
        end
      end

      context 'answers incorrect' do
        let (:current_question) { game_w_questions.current_game_question }
        let (:incorrect_answer_key) { (current_question.variants.keys - [current_question.correct_answer_key]).first }
        let (:prize) { game_w_questions.prize }

        before do
          put :answer, id: game_w_questions.id, letter: incorrect_answer_key
        end

        it 'sends back to main menu' do
          expect(response).to redirect_to user_path(user)
        end

        it 'finishes the game' do
          expect(game.finished?).to be(true)
        end

        it 'returns alert' do
          expect(flash[:alert]).to be
        end

        it 'increases balance by fireproof value' do
          expect(user.balance).to eq prize
        end
      end
    end
  end

  describe '#help' do
    context 'when Guest' do
      before do
        put :help, id: game_w_questions.id, help_type: :audience_help
      end

      it 'returns no positive response' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'returns alert flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when Logged In' do
      before do
        sign_in user
      end

      context 'Audience Help hint' do
        context 'before use' do
          it 'does not have this hint' do
            expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
            expect(game_w_questions.audience_help_used).to be false
            expect(response.status).to be 200
          end
        end

        context 'after use' do
          it 'uses audience help' do
            put :help, id: game_w_questions.id, help_type: :audience_help

            # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
            expect(game.finished?).to be false
            expect(game.audience_help_used).to be true
            expect(game.current_game_question.help_hash[:audience_help]).to be
            expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
            expect(response).to redirect_to(game_path(game))
          end
        end
      end

      context 'Fifty-Fifty hint' do
        context 'before use' do
          it 'does not have this hint' do
            expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
            expect(game_w_questions.fifty_fifty_used).to be false
            expect(response.status).to be 200
          end
        end

        context 'after use' do
          let!(:correct_answer) { game_w_questions.current_game_question.correct_answer_key }
          it 'uses fifty-fifty' do
            put :help, id: game_w_questions.id, help_type: :fifty_fifty

            # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
            expect(game.finished?).to be false
            expect(game.fifty_fifty_used).to be true
            expect(game.current_game_question.help_hash[:fifty_fifty]).to be
            expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq(2)
            expect(game.current_game_question.help_hash[:fifty_fifty]).to include correct_answer
            expect(response).to redirect_to(game_path(game))
          end
        end
      end

      context 'Friend-Call hint' do
        context 'before use' do
          it 'does not have this hint' do
            expect(game_w_questions.current_game_question.help_hash[:friend_call]).not_to be
            expect(game_w_questions.friend_call_used).to be false
            expect(response.status).to be 200
          end
        end

        context 'after use' do
          let!(:answer_key) { game_w_questions.current_game_question.correct_answer_key }

          it 'uses friend call' do
            put :help, id: game_w_questions.id, help_type: :friend_call

            # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
            expect(game.finished?).to be false
            expect(game.friend_call_used).to be true
            expect(game.current_game_question.help_hash[:friend_call]).to be
            expect(game.current_game_question.help_hash[:friend_call]).to be_a String
            expect(game.current_game_question.help_hash[:friend_call][-1].downcase).to match(/[abcd]/)
            expect(response).to redirect_to(game_path(game))
          end
        end
      end
    end
  end

  describe '#take_money' do
    context 'when Guest' do
      before { put :take_money, id: game_w_questions.id }

      it 'returns no positive response' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'returns alert flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when Logged In' do
      before do
        sign_in user
        game_w_questions.update_attribute(:current_level, 2)
      end

      context 'tries to take money' do
        it 'finishes the game with prize' do
          put :take_money, id: game_w_questions.id

          expect(game.finished?).to be true

          expect(game.prize).to eq(200)
          user.reload
          expect(user.balance).to eq(200)

          expect(game.status).to eq :money
          expect(response).to redirect_to(user_path(user))
          expect(flash[:warning]).to be
        end
      end
    end
  end
end
