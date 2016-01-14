defmodule Joining do
	
	def join(peer, {bip, bport}, latlon, listen_port) do
		Network.send_msg({bip, bport, nil}, listen_port, {:ping, latlon})
	end

	defp init_connections(other_ips) do
		other_ips
	end

	def handle_join(reply_to, msg_id, from_link, my_links, my_latlon, listen_port, req_options) do
		Network.send_msg(from_link, listen_port, {:pong, msg_id, my_latlon})
		Enum.each(link, fn link -> Network.send_msg(link, listen_port, {}) end)
	end

end