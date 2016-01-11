# central event dispatcher
# 
# all requests should be served asynchronously
#
# 
defmodule Dispatcher do

	require Logger

	@doc ~S"""
	Init without obtaining other links (i.e. if peer is the first node)
	"""
	def init(latlon, listen_port) do
		this = self
		spawn_link fn -> Network.listen(this, listen_port) end
		loop([], latlon, [], listen_port)
	end

	@doc ~S"""
	Init using the bootstrap_node to get to know other peers
	"""
	def init(bootstrap_node, latlon, listen_port) do
		this = self
		spawn_link fn -> Network.listen(this, listen_port) end
		spawn_link fn -> Joining.join(this, bootstrap_node, latlon) end
		loop([], latlon, [], listen_port)
	end
	
	#
	# links is a set of {id, socket, latlon}-tuples
	# latlon is a {latitude, longitude}-pair
	# data is the collection of data elements held by this peer
	#
	# Do not block in the event handler of this function!
	#
	defp loop(links, latlon, data, listen_port) do
		this = self
		receive do
			{:joined, links} ->
				Logger.info "Successfully joined overlay"
				Logger.info "Current links:\n[#{Enum.join(Enum.map(links, &inspect/1), "\n")}]"
				loop(links, latlon, [], listen_port)
			
			{:newlink, link} ->
				loop([link | links], latlon, data, listen_port)
			
			{:request_join, socket, other_latlon, req_options} ->
				spawn_link fn -> Joining.handle_join(this, socket, latlon, listen_port, other_latlon, req_options) end
				loop(links, latlon, data, listen_port)
			
			{:leave, requestor} ->
				spawn fn -> leave(requestor, links) end
			
			{:query, requestor, other_latlon, query, req_options} ->
				spawn_link fn -> Query.handle(requestor, links, latlon, query) end
				loop(links, latlon, data, listen_port)
			msg ->
				IO.puts "Invalid message #{inspect msg}"
				loop(links, latlon, data, listen_port)
			end
	end

	defp leave(requestor, links) do
		# for each link, tell that you leave
		# close collections
		# return to sender
		send(requestor, {:ok, self()})
	end

end