defmodule Joining do

	require Logger

	def join(peer, state, bootstrap_links) do
		msg_props = %{latlon: state.location}
		msg_props = Network.reset_props(msg_props, state.config)
		msg = {:ping, nil, {state.id, nil, state.listen_port, state.location}}
		msg_id =  Network.get_msg_id(msg, state.config)
		MessageStore.put_own_message(state, msg_id, nil)
		send_all(peer, Enum.map(bootstrap_links, fn {ip, port} -> {nil, ip, port, nil} end), msg_id, msg, msg_props, state)
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
		state
	end

	def announce_join(peer, state) do
		msg_props = %{latlon: state.location}
		msg_props = Network.reset_props(msg_props, state.config)
		msg = {:joined}
		msg_id = Network.get_msg_id(msg, state.config)
		send_all(peer, state.links, msg_id, msg, msg_props, state)
	end

	def handle_join(peer, msg_id, from_link, source_link, state, msg_props) do
		unless MessageStore.is_known_message(state, msg_id) do #Unless we have already seen this ping
			MessageStore.put_other_message(state, msg_id, from_link)
			msg_props = Map.put(msg_props, :latlon, state.location)
			reply(peer, msg_id, from_link, {state.id, nil, state.listen_port, state.location}, msg_props, state)
 			links = Set.delete(state.links, from_link)
 			msg = {:ping, msg_id, source_link}
 			new_msg_id = Network.get_msg_id(msg, state.config)
			send_all(peer, links, new_msg_id, msg, msg_props, state)
		end
	end

	#
	# FIXME: find a nicer way to propagate process errors to Peer
	#
	defp send_all(peer, links, msg_id, msg, msg_props, state) do
		Enum.map( links, fn link -> 
      Logger.debug 'Joining:: Sendling #{inspect msg} to #{inspect links}' 
			spawn_link(fn -> 
					Network.send_and_listen(peer, msg_id, link, msg, msg_props, state)
			end)
		end)
		for _ <- links, do: (
			receive do
				{:EXIT, _pid, {:brokenlink, link, error}} -> Peer.link_broken(peer, link, error)
		 	after
				50 -> # everything fine
		 	end
		 )
	end

	def reply(peer, correlation_id, from_link, new_link, msg_props, state) do
		msg_props = Network.reset_props(msg_props, state.config)
		msg = {:pong, correlation_id, new_link}
		msg_id = Network.get_msg_id(msg, state.config)
		Network.send_and_listen(peer, msg_id, from_link, msg, msg_props, state)
	end

end
