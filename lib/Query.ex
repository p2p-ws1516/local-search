defmodule Query do
	
	def issue(peer, reply_to, {query, opts}, state) do
		msg_props = %{latlon: state.location}
		msg_props = Network.reset_props(msg_props, state.config)
		opts = Keyword.put(opts, :location, state.location)
		msg = {:query, nil, {query, opts}}
		msg_id = Network.get_msg_id(msg, state.config )
		MessageStore.put_own_message(state, msg_id, reply_to)
		send_all(peer, state.links, msg_id, msg, msg_props, state)
	end

	def handle_query(peer, msg_id, from_link, {query, opts}, msg_props, state) do
		unless MessageStore.is_known_message(state, msg_id) do #Unless we have already seen this ping
			MessageStore.put_other_message(state, msg_id, from_link)
			msg_props = Map.put(msg_props, :latlon, state.location)
			case is_query_hit(query, opts, state) do 
				{:ok, matches} -> reply(peer, msg_id, from_link, matches, {nil, state.listen_port, state.location}, msg_props, state) 
				_ -> # Do nothing
			end
			links = Set.delete(state.links, from_link)
			msg = {:query, msg_id, {query, opts}}
			msg_id = Network.get_msg_id(msg, state.config )
			send_all(peer, links, msg_id, msg, msg_props, state)
		end
	end

	defp is_query_hit(query, opts, state) do
		match = true
		if Keyword.has_key?(opts, :location) and Keyword.has_key?(opts, :radius) do
			match = LocationUtil.distance_km(state.location, opts[:location]) <= opts[:radius]
		end
		matches = Enum.filter(state.inventory, fn item -> String.match?(String.downcase(item), Regex.compile!(String.downcase(query))) end)
		if not match or Enum.empty?(matches) do
			{:nomatch}
		else
			{:ok, matches}
		end
	end

	#
	# FIXME: find a nicer way to propagate process errors to Peer
	#
	defp send_all(peer, links, msg_id, msg, msg_props, state) do
		Process.flag(:trap_exit, true)
		Enum.map( links, fn link -> 
				Network.send_and_listen(peer, msg_id, link, msg, msg_props, state) 
		end)
	end

	def reply(peer, correlation_id, link, query, owner, msg_props, state) do
		msg_props = Network.reset_props(msg_props, state.config)
		msg = {:query_hit, correlation_id, query, owner}
		msg_id = Network.get_msg_id(msg, state.config)
		Network.send_and_listen(peer, msg_id, link, msg, msg_props, state)
	end

end