# frozen_string_literal: true

module Main
  module Actions
    module Chat
      class Show < Action::Base
        def handle(req, res)
          res[:room] = req.params[:id]
          res[:username] = req.params[:username]
        end
      end
    end
  end
end
