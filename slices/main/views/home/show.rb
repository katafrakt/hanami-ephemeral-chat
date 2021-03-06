# frozen_string_literal: true

module Main
  module Views
    module Home
      class Show < View::Base
        expose :room do
          SecureRandom.uuid
        end
      end
    end
  end
end
