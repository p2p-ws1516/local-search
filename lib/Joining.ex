defmodule Joining do
	
	def join(peer, state, {bip, bport}, latlon, listen_port) do
		IO.puts "#{inspect peer} is joining"
		msg_id = Network.send_msg({bip, bport, nil}, listen_port, {:ping, nil, latlon})
		MessageStore.put_own_message(state, msg_id)
	end

	def handle_join(msg_id, from_link, state, req_options) do
		MessageStore.put_other_message(state, msg_id, from_link)
		reply(msg_id, from_link, {nil, state.listen_port, state.location}, state, req_options)
		from_latlon = Network.latlon(from_link) 
		Enum.each(
			state.links, 
			fn link -> 
				Network.send_msg(link, state.listen_port, {:ping, msg_id, from_latlon}) end)
	end

	def reply(correlation_id, from_link, new_link, state, req_options) do
		Network.send_msg(from_link, state.listen_port, {:pong, correlation_id, new_link})
	end

end
