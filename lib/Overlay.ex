# Facade for handling all overlay operations from the front end
#
# 
defmodule Overlay do
	
	#@spec join(bootstrap_ip_address, latlon) :: {status, dispatcher_pid}
	def join(bootstrap_ip_address, latlon) do
		IO.puts "Joining overlay using bootstrap IP #{format_ipv4(bootstrap_ip_address)} at #{format_latlon(latlon)}"
		spawn_link fn -> Dispatcher.init(bootstrap_ip_address, latlon) end
	end

	def query(dispatcher_pid, latlon, query) do
		
	end

	def leave(dispatcher_pid) do
		send(dispatcher_pid, {:leave, self()})
		receive do
			{:ok} ->
		    	IO.puts "Successfully finished"
		    msg ->
		    	IO.puts "Leaving the network failed with #{msg}"
		end
	end

	defp format_ipv4({ip1, ip2, ip3, ip4}) do
		"#{ip1}.#{ip2}.#{ip3}.#{ip4}."
	end

	defp format_latlon({lat, lon}) do
		"lat: #{lat}, lon: #{lon}"
	end

end