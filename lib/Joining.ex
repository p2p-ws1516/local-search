defmodule Joining do
	
	def join(peer, state, {bip, bport}, latlon, listen_port) do
		msg_id = Network.send_msg({bip, bport, nil}, listen_port, latlon, {:ping, nil, {nil, listen_port, latlon}} )
		MessageStore.put_own_message(state, msg_id)
	end

	def handle_join(peer, msg_id, from_link, source_link, state, req_options) do
		unless MessageStore.is_other_message(state, msg_id) do #Unless we have already seen this ping
			MessageStore.put_other_message(state, msg_id, source_link)
			reply(msg_id, from_link, {nil, state.listen_port, state.location}, state, req_options)
			Enum.each(
				Set.delete(state.links, from_link), 
				fn link -> 
					Network.send_msg(link, state.listen_port, state.location, {:ping, msg_id, source_link}) end)
			Peer.suggest_link(peer, from_link)
			Peer.suggest_link(peer, source_link)
		end
	end

	def reply(correlation_id, from_link, new_link, state, req_options) do
		Network.send_msg(from_link, state.listen_port, state.location, {:pong, correlation_id, new_link})
	end

end
