defmodule Joining do
	
	def join(dispatcher, bootstrap_ip, latlon) do
		# init TCP connection
		# handle socket
		# wait synchronously
		# get a bunch of ip addresses
		other_ips = []
		links = init_connections(other_ips)
		send(dispatcher, {:Joined, links})
	end

	defp init_connections(other_ips) do

	end

	def handle_join(dispatcher, links, my_latlon, other_latlon, req_options) do

	end

end