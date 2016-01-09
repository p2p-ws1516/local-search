defmodule Joining do
	
	def join(dispatcher, bootstrap_ip, latlon) do
		# init TCP connection
		# handle socket
		# wait synchronously
		# get a bunch of ip addresses
		other_ips = ["1.0.0.1", "1.0.0.2"]
		links = init_connections(other_ips)
		send dispatcher, {:joined, links}
	end

	defp init_connections(other_ips) do
		other_ips
	end

	def handle_join(dispatcher, links, my_latlon, other_latlon, req_options) do

	end

end