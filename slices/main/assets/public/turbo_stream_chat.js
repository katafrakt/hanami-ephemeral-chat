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