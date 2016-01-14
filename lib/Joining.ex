defmodule Joining do
	
	def join(peer, {bip, bport}, latlon, listen_port) do
		Network.send_msg({bip, bport, nil}, listen_port, {:ping, nil, latlon})
	end

	def handle_join(reply_to, msg_id, from_link, state, req_options) do
		Network.send_msg(from_link, state.listen_port, {:pong, msg_id, state.location})
		{_,_,from_latlon} = from_link
		Enum.each(
			state.links, 
			fn link -> 
				Network.send_msg(link, state.listen_port, {:ping, msg_id, from_link}) end)
	end

end
