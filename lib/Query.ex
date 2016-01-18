defmodule Query do
	
	def issue(peer, reply_to, query, state) do
		msg_props = %{replyport: state.listen_port, latlon: state.location}
		msg_props = Network.reset_props(msg_props, state.config)
		msg = {:query, nil, query}
		msg_id = Network.get_msg_id(msg, state.config )
		MessageStore.put_own_message(state, msg_id, reply_to)
		send_all(peer, state.links, msg_id, msg, msg_props, state)
	end

	def handle_query(peer, msg_id, from_link, query, msg_props, state) do
		unless MessageStore.is_known_message(state, msg_id) do #Unless we have already seen this ping
			MessageStore.put_other_message(state, msg_id, from_link)
			msg_props = Map.put(msg_props, :replyport, state.listen_port)
			msg_props = Map.put(msg_props, :latlon, state.location)
			if is_query_hit(query, state) do 
				reply(msg_id, from_link, query, {nil, state.listen_port, state.location}, msg_props, state) 
			end
			links = Set.delete(state.links, from_link)
			msg = {:query, msg_id, query}
			msg_id = Network.get_msg_id(msg, state.config )
			send_all(peer, links, msg_id, msg, msg_props, state)
		end
	end

	defp is_query_hit(query, state) do
		Enum.member?(state.inventory, query)
	end

	#
	# FIXME: find a nicer way to propagate process errors to Peer
	#
	defp send_all(peer, links, msg_id, msg, msg_props, state) do
		Process.flag(:trap_exit, true)
		Enum.map( links, fn link -> spawn_link(
			fn -> 
				Network.send_msg(msg_id, link, msg, msg_props, state.config) 
			end) end)
		for _ <- links, do: (
			receive do
				{:EXIT, _, {:brokenlink, link, error}} -> Peer.link_broken(peer, link, error)
		 	after
				500 ->
		 	end
		 )
	end

	def reply(correlation_id, link, query, owner, msg_props, state) do
		msg_props = Network.reset_props(msg_props, state.config)
		msg = {:query_hit, correlation_id, query, owner}
		msg_id = Network.get_msg_id(msg, state.config)
		Network.send_msg(msg_id, link, msg, msg_props, state.config)
	end

end