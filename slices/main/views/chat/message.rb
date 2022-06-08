# frozen_string_literal: true

require "hanami/utils/escape"

module Main
  module Views
    module Chat
      class Message < View::Base
        expose :is_system
        config.layout = false

        expose :message do |message:, is_system:|
          if is_system
            message
          else
            Hanami::Utils::Escape.html(message)
          end
        end

        expose :user do |user:|
          Hanami::Utils::Escape.html(user)
        end

        expose :time do
          Time.now.strftime("%H:%M:%S")
        end
      end
    end
  end
end
