# (c) goodprogrammer.ru

require 'rails_helper'

# Тестовый сценарий для модели Вопрос
# Вопрос не содержит функционала (это просто хранилище данных),
# поэтому все тесты сводятся только к проверке наличия нужных валидаций.
#
# Обратите внимание, что работу самих валидаций не надо тестировать (это работа
# авторов rails). Смысл именно в проверке _наличия_ у модели конкретных валидаций.
RSpec.describe Question, type: :model do

  context 'when validations called' do
    it 'validates presence of :text' do
      should validate_presence_of :text
    end
    it 'validates presence of :level' do
      should validate_presence_of :level
    end

    it 'validates :level inclusion' do
      should validate_inclusion_of(:level).in_range(0..14)
    end

    it 'allows value of :level < 15' do
      should allow_value(14).for(:level)
      should_not allow_value(15).for(:level)
    end
  end
end
