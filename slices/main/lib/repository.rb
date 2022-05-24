# auto_register: false
# frozen_string_literal: true

require "ephemeral_chat/repository"

module Main
  class Repository < EphemeralChat::Repository
    struct_namespace Entities
  end
end
