# central event dispatcher
# 
# all requests should be served asynchronously
#
# 
defmodule Dispatcher do

	def init(bootstrap_ip, latlon) do
		spawn_link &Joining.join(bootstrap_ip, latlon, self())
		receive do # queue all other messages unless we haven't joined
			{:joined, links} ->
				IO.puts "Successfully joined overlay"
				spawn_link &listen(links, self())
				loop(links, latlon, [])
		end
	end

	defp listen(links, dispatcher) do
		# listen to sockets and handle messages from them
		# forward to dispatcher
	end

	#
	# links is a set of {id, socket, latlon}-tuples
	# latlon is a {latitude, longitude}-pair
	# data is the collection of data elements held by this peer
	#
	# Do not block in the event handler of this function!
	#
	defp loop(links, latlon, data) do
		receive do
			{:join, other_ip, other_latlon, req_options} ->
				spawn_link &Joining.handle_join(self(), links, latlon, other_latlon, req_options)
		    	loop(links, latlon, data)
		    {:leave, requestor} ->
		    	spawn &leave(requestor, links, data)
		    {:query, requestor, other_latlon, query, req_options} ->
		    	spawn_link &Query.handle(requestor, links, latlon, query)
		    	loop(links, latlon, data)
		    msg ->
		    	IO.puts "Invalid message #{msg}"
		    	loop(links, latlon, data)
		end
	end

	defp leave(requestor, links) do
		# for each link, tell that you leave
		# close collections
		# return to sender
		send(requestor, {:ok, self()})
	end

end