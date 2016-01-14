defmodule Joining do
	
	def join(peer, {bip, bport}, latlon, listen_port) do
		Network.send_msg({bip, bport, nil}, listen_port, {:ping, latlon})
	end

	def handle_join(reply_to, msg_id, from_link, state, req_options) do
		Network.send_msg(from_link, state.listen_port, {:pong, msg_id, state.location})
		# Enum.each(link, fn link -> Network.send_msg(link, listen_port, {}) end)
	end

end
