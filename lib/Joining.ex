defmodule Joining do
	
	def join(peer, state, {bip, bport}) do
		msg_props = %{replyport: state.listen_port, latlon: state.location}
		msg_props = Network.reset_props(msg_props, state.config)
		msg_id = Network.send_msg({bip, bport, nil}, {:ping, nil, {nil, state.listen_port, state.location}}, msg_props )
		MessageStore.put_own_message(state, msg_id)
	end

	def handle_join(peer, msg_id, from_link, source_link, state, msg_props) do
		unless MessageStore.is_other_message(state, msg_id) do #Unless we have already seen this ping
			MessageStore.put_other_message(state, msg_id, source_link)
			msg_props = Map.put(msg_props, :replyport, state.listen_port)
			msg_props = Map.put(msg_props, :latlon, state.location)
			reply(msg_id, from_link, {nil, state.listen_port, state.location}, state, msg_props)
			Enum.each(
				Set.delete(state.links, from_link), 
				fn link -> 
					Network.send_msg(link, {:ping, msg_id, source_link}, msg_props) end)
			Peer.suggest_link(peer, from_link)
			Peer.suggest_link(peer, source_link)
		end
	end

	def reply(correlation_id, from_link, new_link, state, msg_props) do
		msg_props = Network.reset_props(msg_props, state.config)
		Network.send_msg(from_link, {:pong, correlation_id, new_link}, msg_props)
	end

end
