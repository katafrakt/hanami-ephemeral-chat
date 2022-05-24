# frozen_string_literal: true

require "hanami/application/routes"

module EphemeralChat
  class Routes < Hanami::Application::Routes
    define do
      slice :main, at: "/" do
        get "/ws", to: ->(env) { EphemeralChat::WebsocketChat.handle(env) }
        get "/chat/:id", to: "chat.join"
        post "/chat/:id", to: "chat.show"
        post "/chat/:id/message", to: "chat.add_message"
        root to: "home.show"
      end
    end
  end
end
