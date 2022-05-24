# frozen_string_literal: true

module Main
  module Views
    module Chat
      class AddMessage < View::Base
        expose :room, :username
      end
    end
  end
end