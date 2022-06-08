# frozen_string_literal: true

module Main
  module Views
    module Chat
      class AddMessage < View::Base
        expose :room

        expose :username do |username:|
          Hanami::Utils::Escape.html(username)
        end
      end
    end
  end
end
