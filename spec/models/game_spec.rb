# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для модели Игры
# В идеале - все методы должны быть покрыты тестами,
# в этом классе содержится ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { FactoryGirl.create(:user) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  # Группа тестов на работу фабрики создания новых игр
    describe '#create_game!' do
      it 'creates new correct game' do
        # генерим 60 вопросов с 4х запасом по полю level,
        # чтобы проверить работу RANDOM при создании игры
        generate_questions(60)

        game = nil
        # создaли игру, обернули в блок, на который накладываем проверки
        expect {
          game = Game.create_game_for_user!(user)
        }.to change(Game, :count).by(1).and(# проверка: Game.count изменился на 1 (создали в базе 1 игру)
          change(GameQuestion, :count).by(15).and(# GameQuestion.count +15
            change(Question, :count).by(0) # Game.count не должен измениться
          )
        )
        # проверяем статус и поля
        expect(game.user).to eq(user)
        expect(game.status).to eq(:in_progress)
        # проверяем корректность массива игровых вопросов
        expect(game.game_questions.size).to eq(15)
        expect(game.game_questions.map(&:level)).to eq (0..14).to_a
      end
    end

    describe '#answer_current_question!' do
      context 'when answer is correct' do
        let!(:answer_key) { game_w_questions.current_game_question.correct_answer_key }

        context 'when question is last' do
          let!(:last_level) { Game::FIREPROOF_LEVELS.last }
          let!(:max_prize) { Game::PRIZES.last }

          before do
            game_w_questions.current_level = last_level
            game_w_questions.prize = Game::PRIZES[-2]
          end

          it 'assigns final prize' do
            game_w_questions.answer_current_question!(answer_key)
            expect(game_w_questions.prize).to eq(max_prize)
          end

          it 'finishes game with status :won' do
            game_w_questions.answer_current_question!(answer_key)
            expect(game_w_questions.finished?).to be true
            expect(game_w_questions.status).to eq :won
          end
        end

        context 'when question is NOT last' do
          let(:level) { rand(0..Game::FIREPROOF_LEVELS.last - 1) }
          before do
            game_w_questions.current_level = level
          end

          it 'moves to the next level' do
            game_w_questions.answer_current_question!(answer_key)
            expect(game_w_questions.current_level).to eq(level + 1)
          end

          it 'continues game' do
            game_w_questions.answer_current_question!(answer_key)
            expect(game_w_questions.finished?).to be false
            expect(game_w_questions.status).to eq :in_progress
          end
        end
      end

      context 'answer is NOT correct' do
        let!(:current_question) { game_w_questions.current_game_question }
        let!(:answer_key) do
          (current_question.variants.keys - [current_question.correct_answer_key]).first
        end

        it 'finishes the game with status :fail' do
          game_w_questions.answer_current_question!(answer_key)
          expect(game_w_questions.finished?).to be true
          expect(game_w_questions.status).to eq :fail
        end

        it 'increases balance by fireproof value' do
          game_w_questions.answer_current_question!(answer_key)
          prize = game_w_questions.prize
          expect(user.balance).to eq prize
        end
      end

      context 'when time is over' do
        let(:answer_key) { %w[a b c d].sample }
        before do
          game_w_questions.created_at = 1.hour.ago
        end

        it 'finishes game with status :timeout' do
          game_w_questions.answer_current_question!(answer_key)
          expect(game_w_questions.finished?).to be true
          expect(game_w_questions.status).to eq :timeout
        end
      end
    end

    describe '#take_money!' do
      before do
        q = game_w_questions.current_game_question
        game_w_questions.answer_current_question!(q.correct_answer_key)
      end

      it 'prize has positive value' do
        game_w_questions.take_money!
        prize = game_w_questions.prize
        expect(prize).to be > 0
      end

      it 'game status is :money' do
        game_w_questions.take_money!
        expect(game_w_questions.status).to eq :money
      end

      it 'game is finished' do
        game_w_questions.take_money!
        expect(game_w_questions.finished?).to be true
      end

      it 'balance is correctly increased' do
        game_w_questions.take_money!
        prize = game_w_questions.prize

        expect(user.balance).to eq prize
      end
    end

    describe '#current_game_question' do
      let(:level) { rand(0..Question::QUESTION_LEVELS.last) }

      before do
        game_w_questions.current_level = level
      end

      it 'returns current question' do
        expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions[level])
      end
    end

    describe '#previous_level' do
      it 'should contain previous level' do
        expect(game_w_questions.previous_level).to eq game_w_questions.current_level - 1
      end
    end

    describe '#status' do
      before(:each) do
        game_w_questions.finished_at = Time.now
        expect(game_w_questions.finished?).to be true
      end

      context 'when max level passed' do
        it 'returns :won' do
          game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
          expect(game_w_questions.status).to eq(:won)
        end
      end

      context 'when game is failed' do
        it 'returns :fail' do
          game_w_questions.is_failed = true
          expect(game_w_questions.status).to eq(:fail)
        end
      end

      context 'when game is longer than 1h' do
        it 'returns :timeout' do
          game_w_questions.created_at = 1.hour.ago
          game_w_questions.is_failed = true
          expect(game_w_questions.status).to eq(:timeout)
        end
      end

      context 'when no previous conditions matched' do
        it 'returns :money' do
          expect(game_w_questions.status).to eq(:money)
        end
      end
    end
  end
