# frozen_string_literal: true
require "hanami/utils/escape"

module Main
  module Views
    module Chat
      class Show < View::Base
        expose :room

        expose :username do |username:|
          Hanami::Utils::Escape.html(username)
        end
      end
    end
  end
end
