# (c) goodprogrammer.ru

require 'rails_helper'

# Тестовый сценарий для модели игрового вопроса,
# в идеале весь наш функционал (все методы) должны быть протестированы.
RSpec.describe GameQuestion, type: :model do

  # задаем локальную переменную game_question, доступную во всех тестах этого сценария
  # она будет создана на фабрике заново для каждого блока it, где она вызывается
  let(:game_question) { FactoryGirl.create(:game_question, a: 2, b: 1, c: 4, d: 3) }

  # группа тестов на игровое состояние объекта вопроса
  describe '#level' do
    context 'when delegated' do
      it 'returns correct value' do
        expect(game_question.level).to eq(game_question.question.level)
      end
    end
  end

  describe '#text' do
    context 'when delegated' do
      it 'returns correct value' do
        expect(game_question.text).to eq(game_question.question.text)
      end
    end
  end

  describe '#variants' do
    context 'when hash is generated' do
      it 'is correct' do
        expect(game_question.variants).to eq({'a' => game_question.question.answer2,
                                              'b' => game_question.question.answer1,
                                              'c' => game_question.question.answer4,
                                              'd' => game_question.question.answer3})
      end
    end
  end

  describe '#answer_correct?' do
    context 'when called with correct answer' do
      it 'returns true' do
        expect(game_question.answer_correct?('b')).to be true
      end
    end
  end

  describe '#correct_answer_key' do
    context 'when called' do
      it 'returns correct answer key' do
        expect(game_question.correct_answer_key).to eq('b')
      end
    end
  end

  # help_hash у нас имеет такой формат:
  # {
  #   fifty_fifty: ['a', 'b'], # При использовании подсказски остались варианты a и b
  #   audience_help: {'a' => 42, 'c' => 37 ...}, # Распределение голосов по вариантам a, b, c, d
  #   friend_call: 'Василий Петрович считает, что правильный ответ A'
  # }
  #

  describe '#help_hash' do
    it 'returns Hash' do
      expect(game_question.help_hash).to be_a Hash
    end
  end

  describe '#add_audience_help' do
    context 'player uses audience_help hint' do
      let(:ah) { game_question.help_hash[:audience_help] }

      context 'before use' do
        it 'has no hint in the hash' do
          expect(game_question.help_hash).not_to include(:audience_help)
        end
      end

      context 'after use' do
        before { game_question.add_audience_help }

        it 'adds hint to help hash' do
          expect(game_question.help_hash).to include(:audience_help)
        end

        it 'uses hint correctly' do
          expect(ah.keys).to contain_exactly('a', 'b', 'c', 'd')
        end
      end
    end
  end

  describe '#add_fifty_fifty' do
    context 'player uses fifty_fifty hint' do
      let(:ff) { game_question.help_hash[:fifty_fifty] }

      context 'before use' do
        it 'has no hint in the hash' do
          expect(game_question.help_hash).not_to include(:fifty_fifty)
        end
      end

      context 'after use' do
        before { game_question.add_fifty_fifty }

        it 'adds hint to help hash' do
          expect(game_question.help_hash).to include(:fifty_fifty)
        end

        it 'leaves correct answer' do
          expect(ff).to include('b')
        end
        it 'leaves 2 answers' do
          expect(ff.size).to eq 2
        end
      end
    end
  end

  describe '#add_friend_call' do
    context 'when player uses friend_call hint' do
      let(:fc) { game_question.help_hash[:friend_call] }

      context 'before use' do
        it 'has no hint in the hash' do
          expect(game_question.help_hash).not_to include(:friend_call)
        end
      end

      context 'after use' do
        before { game_question.add_friend_call }

        it 'adds hint to help hash' do
          expect(game_question.help_hash).to include(:friend_call)
        end

        it 'uses hint correctly' do
          expect(fc).to be_a String
        end
      end
    end
  end
end
