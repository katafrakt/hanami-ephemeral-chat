# frozen_string_literal: true

require "hanami"

module EphemeralChat
  class Application < Hanami::Application
    config.sessions = :cookie, {
      key: "ephemeral_chat.session",
      secret: settings.session_secret,
      expire_after: 60 * 60 * 24 * 365 # 1 year
    }

    config.actions.content_security_policy[:connect_src] = "ws: 'self'"
    config.actions.content_security_policy[:default_src] = "*"
    config.actions.content_security_policy[:style_src] = "*"
    config.actions.content_security_policy[:script_src] = "*"
  end
end
