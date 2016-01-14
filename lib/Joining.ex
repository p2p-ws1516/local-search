defmodule Joining do
	
	def join(peer, {bip, bport}, latlon, listen_port) do
		joined_reply = Network.send_and_recv_msg({bip, bport, nil}, listen_port, {:ping, latlon})
		send(peer, joined_reply)
	end

	defp init_connections(other_ips) do
		other_ips
	end

	def handle_join(reply_to, msg_id, link, my_latlon, listen_port, req_options) do
		# determine links
		Network.send_msg(link, listen_port, {:pong, msg_id, my_latlon})
	end

end