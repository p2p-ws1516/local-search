defmodule Joining do
	
	def join(peer, state, {bip, bport}) do
		msg_props = %{replyport: state.listen_port, latlon: state.location}
		msg_props = Network.reset_props(msg_props, state.config)
		msg_id = Network.send_msg({bip, bport, nil}, {:ping, nil, {nil, state.listen_port, state.location}}, msg_props )
		MessageStore.put_own_message(state, msg_id)
	end

	@doc ~S"""
	Selects state.config[:maxlinks] new links from state.pending_links and puts them into state.links
	
	##Example
	iex>pending = Enum.into [{{127,0,0,1}, 8080, {1,2}},{{127,0,0,2}, 9090, {3,4}},{{127,0,0,3}, 7070, {5,6}}], HashSet.new
	iex>Set.size(pending)
	3
	iex>links = HashSet.new
	iex>state = %{config: [maxlinks: 2], pending_links: pending, links: links}
	iex>state = Joining.select_links(state)
	iex>Set.size(state.links)
	2 
	iex>Set.size(state.pending_links)
	0

	##Example
	iex>pending = Enum.into [{{127,0,0,1}, 8080, {1,2}},{{127,0,0,2}, 9090, {3,3}}], HashSet.new
	iex>Set.size(pending)
	iex>links = Enum.into [{{127,0,0,1}, 8080, {1,2}}], HashSet.new
	iex>state = %{config: [maxlinks: 1], pending_links: pending, links: links}
	iex>state = Joining.select_links(state)
	iex>state.links
	Enum.into [{{127,0,0,1}, 8080, {1,2}}], HashSet.new
	iex>Set.size(state.pending_links)
	0
	
	##Example
	iex>pending = Enum.into [{{127,0,0,1}, 8080, {1,2}},{{127,0,0,2}, 9090, {3,3}}], HashSet.new
	iex>Set.size(pending)
	iex>links = Enum.into [{{127,0,0,1}, 8080, {1,2}}], HashSet.new
	iex>state = %{config: [maxlinks: 2], pending_links: pending, links: links}
	iex>state = Joining.select_links(state)
	iex>state.links
	Enum.into [{{127,0,0,1}, 8080, {1,2}}, {{127,0,0,2}, 9090, {3,3}}], HashSet.new
	iex>Set.size(state.pending_links)
	0
	
	##Example
	iex>pending = Enum.into [{{127,0,0,1}, 8080, {1,2}},{{127,0,0,2}, 9090, {3,3}}, {{127,0,0,3}, 7070, {4,4}}], HashSet.new
	iex>Set.size(pending)
	iex>links = Enum.into [{{127,0,0,1}, 8080, {1,2}}], HashSet.new
	iex>state = %{config: [maxlinks: 2], pending_links: pending, links: links}
	iex>state = Joining.select_links(state)
	iex>Set.size(state.links)
	2
	iex>Set.size(state.pending_links)
	0

	"""
	def select_links(state) do
		newlinks = Set.difference(state.pending_links, state.links)
	    links = Set.to_list(newlinks) |> Enum.shuffle |> Enum.take(state.config[:maxlinks] - Set.size(state.links))
      	state = Map.update!(state, :links, fn old -> Set.union(old, Enum.into(links, HashSet.new)) end)
      	state = Map.put(state, :pending_links, HashSet.new)
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
