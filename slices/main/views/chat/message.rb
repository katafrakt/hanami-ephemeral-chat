# frozen_string_literal: true

require "hanami/utils/escape"

module Main
  module Views
    module Chat
      class Message < View::Base
        expose :user
        expose :is_system
        config.layout = false

        expose :message do |message:|
          Hanami::Utils::Escape.html(message)
        end

        expose :time do
          Time.now.strftime("%H:%M:%S")
        end
      end
    end
  end
end