defmodule Joining do
	
	def join(peer, bootstrap_node, latlon) do
		joined_reply = Network.send_and_recv_msg(bootstrap_node, {:request_join, latlon})
		send(peer, joined_reply)
	end

	defp init_connections(other_ips) do
		other_ips
	end

	def handle_join(peer, socket, my_latlon, myport, other_latlon, req_options) do
		# determine links
		links = [{{127,0,0,1}, myport, my_latlon}]
		Network.send_msg(socket, {:grant_join, links})
	end

end