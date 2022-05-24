module EphemeralChat
  class WebsocketChat
    attr_reader :room_name

    def self.handle(env)
      if env['rack.upgrade?'.freeze] == :websocket 
        req = Rack::Request.new(env)
        env['rack.upgrade'.freeze] = new(req.params["room"], req.params["user"])
        [0,{}, []]
      end
    end

    def initialize(room_name, user)
      @room_name = room_name || "default"
      @user = user
    end

    def on_open(client)
      client.subscribe(room_name) do |source, data|
        data = JSON.parse(data)
        response = Main::Views::Chat::Message.new.(message: data["message"], user: data["user"], is_system: data["system"]).to_s
        client.write(response)
      end

      client.publish(room_name, %[{"user": "", "system": true, "message": "#{@user} has joined"}])
    end

    def on_message(client, message)
      data = JSON.dump({ user: @user, message: message})
      client.publish(room_name, data)
    end
    
    def on_close(client)
      client.publish(room_name, %[{"user": "", "system": true, "message": "#{@user} has left"}])
    end
  end
end