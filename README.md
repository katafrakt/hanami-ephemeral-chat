
# Hanami Ephemeral Chat

![](https://user-images.githubusercontent.com/119904/170112436-134e8778-e407-473c-a737-d8377413af32.png)

This is an experiment to create a simple chat application using [Hanami](https://github.com/hanami/hanami) and [Hotwire](https://hotwired.dev/) on top of [Iodine](https://github.com/boazsegev/iodine) server.  It does not use any persistence - messages are delivered to all users connected to current room, but are not stored anywhere and cannot be accessed later.

### Why Hanami?

Hanami is a next-gen web framework which attempts to solve problems that Rails-way promotes. It is currently approaching version 2.0 (this app is build on top of alpha 8.1 version) so it's high time to give it a go.

### Why Hotwire?

Hotwire is a new hot for JS-less development, lately introduced by Rails team. On of the things it advertises are Turbo Streams, i.e. the way to get live updates from the server to the client. Also, Hotwire claims that it's not tightly coupled to Rails. Since I like the idea of HTML-over-the-wire and I wanted to check if it really works well outside of Rails, I decided to try it.

### Why Iodine?

Iodine is a high performant web server rfor Ruby application, built with Websockets support and PubSub - all this making it perfect for this kind of the task. Achieving PubSub in Ruby web development world without relying on external services (like Redis of PostgreSQL's LISTEN/NOTIFY) is rather a hard task, so having a solution that _just does that_ reduces a lot of traction.

It might feel strange for a seasoned Ruby developers to rely so heavily upon a webserver. After all, we are used to treat them as transparent pieces of our applications and part of infrastructure. We never really cared if the app was supposed to be run on Puma, Unicorn or standalone passenger. I think that when we talk about apps like chats, we can no longer pretend it does not matter. Using a _right tool for the job_ (Iodine in this case) saved probably hours of trying to come of with alternative, server-agnostic solution.

## Important pieces

### Turbo stream web component

First and important thing is that I had to create a custom web component handling a Turbo Stream over WebSockets. This was largely ~~inpired~~ copied from the implementation from [turbo-rails](https://github.com/hotwired/turbo-rails). Sidenote: Hotwire at its core is a pretty simple set of tools, but it's `turbo-rails` that makes it powerful. Unsurprising, `turbo-rails` is **very** coupled to Rails. Anyway, the web component:

```javascript
import { connectStreamSource, disconnectStreamSource } from "@hotwired/turbo"

class TurboStreamChatElement extends HTMLElement {
  async connectedCallback() {
    connectStreamSource(this)
    this.socket = this.createSocket(this.channel, { received: this.dispatchMessageEvent.bind(this) })
  }

  disconnectedCallback() {
    disconnectStreamSource(this)
    if (this.subscription) this.subscription.unsubscribe()
  }

  dispatchMessageEvent(data) {
    const event = new MessageEvent("message", { data: data.data })
    return this.dispatchEvent(event)
  }

  createSocket(_channel, callbacks) {
    const room = this.getAttribute("room");
    const user = this.getAttribute("username");
    let socket = new WebSocket(`ws://${window.location.host}/ws?user=${user}&room=${room}`);
    socket.onmessage = callbacks.received;
    return socket
  }
}

customElements.define("turbo-stream-chat", TurboStreamChatElement)
```

With that, we just need to put a correct code in one of our templates:

```html
<turbo-stream-chat room="<%= room %>" username="<%= username %>"></turbo-stream-chat>
```

This connects to a given room using a given username - by passing params to generic `/ws` endpoint.

### Actual WebSocket implementation

The whole WebSocket handler is just a one class:

```ruby
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
```

The `self.handle(env)` is a handler for WebSocket endpoint, as described in Iodine's README. Inside we instantiate a new `WebsocketChat` object, which holds room name and current username. This object implements three methods:

* `on_open` – this happens when a new connection to a WebSocket endpoint is created. It subscribes the client to a channel with a name of the room. Inside the subscription is the code executed upon each received message, which is: parse the data (is must be a string in Iodine) and render a response. It also broadcasts a message that a new user has joined the room, using `client.publish` method.
* `on_message` happens on each message received by the WebSocket, i.e. when a user sends a message to the chat. It is really simple: just craete a JSON message and broadcast it to the channel.
* `on_close` serves the disconnection - it broadcasts the information that the user left the chat.

The `Main::Views::Chat::Message` view just renders Turbo-specific HTML template:

```html
<turbo-stream action="append" target="messages">
  <template>
    <div class="row" id="<%= SecureRandom.uuid %>">
      <div class="column column-80">
        <% if is_system %>
        <em><%= message %></em>
        <% else %>
        [<strong><%= user %></strong>]
        <%= message %>
        <% end %>
      </div>
      <div class="column column-20">
        <%= time %>
      </div>
    </div>
  </template>
</turbo-stream>
```

It instructs frontend Hotwire lib to append the content (the inner HTML of `<template>` tag to the element with id `messages`). That's it. We don't have to do anything more.

### Routes etc.

Finally, we have to add some routes and other standard Hanami things, like other views and actions. The routing part looks like this:

```ruby
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
```

* `/ws` - we have already covered, it's the whole WebSockets machinery
* `/chat/:id` via GET - render a form asking a user to input their username and then taking them to the chat itself
* `/chat/:d` via POST - the actual chat. POST is a hack so that the URL can be copied from the browser address bar without containing a room name and a user name, also forcing the user to go through the username-setting step.
* `/chat/:id/message` is hit when a user inputs a message in a input on a chat view and hits enter. By the power of Turbo Drive (which we got for free when including Hotwire, whether we want it or not) takes care of sending it asynchronously, without reloading the page, so in the controller part we can just treat it as a regular endpoint. Here's the code for this action:

```ruby
def handle(req, res)
  message = req.params[:message]
  user = req.params[:user]
  
  data = JSON.dump({ user: user, message: message})
  Iodine.publish(req.params[:id], data)

  res[:room] = req.params[:id]
  res[:username] = req.params[:user]
end
```

Note that we are calling `Iodine.publish` here, again coupling with the server, but doing it only at controller level - which is kind of infrastructural anyway.

Another trick that happens here is that we are rendering... template of an empty chatroom's form at the end. Why? Because it contains a `turbo-frame`:

```html
<turbo-frame id="chat-controls">
  <form class="chat-controls" data-turbo="true"
      method="POST" action="/chat/<%= room %>/message">
    <input type="text" name="message" autocomplete="false" autofocus />
    <input type="hidden" name="user" value="<%= username %>" />
  </form>
</turbo-frame>
```

Seeing this, Hotwire replaces a current form element (a `<turbo-frame>` with id `chat-controls`) with an empty one - so we have reset the input (that contained the message we just sent) with it and have form clearing without any JavaScript coding involved.

## Summary

This exercise required a lot if investigating how `turbo-rails` and Hotwire in general work. However, after having done this work it is really pretty simple glue code. I think the choice of the bricks was pretty smart in this case:

* Hanami - gave the router and full-featured view rendering, with layouts etc. Of course, this could be replaced with something simpler, like [Rack App](http://www.rack-app.com/), but with that we'll be on our own with assets and templates.
* Hotwire - aside from the web component, this app does not contain a single line of JavaScript code, while still behaves like a SPA application.
* Iodine - not having to reimplement WebSocket support and PubSub is cool, even if you have to rely on the choice of the webserver a bit more than you are used to.

Summing up, pretty cool.