# frozen_string_literal: true

module Main
  module Actions
    module Chat
      class AddMessage < Action::Base
        def handle(req, res)
          message = req.params[:message]
          user = req.params[:user]
          
          data = JSON.dump({ user: user, message: message})
          Iodine.publish(req.params[:id], data)

          res[:room] = req.params[:id]
          res[:username] = req.params[:user]
        end
      end
    end
  end
end
