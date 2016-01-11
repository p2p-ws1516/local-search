# Facade for handling all overlay operations from the front end
#
defmodule Overlay do
	
	require Logger

	def join(bootstrap_node, latlon, listen_port, init) do
		if init do
			spawn_link fn -> Dispatcher.init(latlon, listen_port) end
			Logger.info "Initial node in overlay at #{format_latlon(latlon)}"
		else 
			spawn_link fn -> Dispatcher.init(bootstrap_node, latlon, listen_port) end
			Logger.info "Joining overlay using bootstrap node #{Network.format(bootstrap_node)} at #{format_latlon(latlon)}"
		end
	end

	def query(dispatcher_pid, latlon, query) do
		
	end

	def leave(dispatcher_pid) do
		send(dispatcher_pid, {:leave, self()})
		receive do
			{:ok} ->
		    	Logger.info "Successfully finished"
		    msg ->
		    	Logger.info "Leaving the network failed with #{msg}"
		end
	end

	defp format_latlon({lat, lon}) do
		"lat: #{lat}, lon: #{lon}"
	end

end