# Facade for handling all overlay operations from the front end
#
# 
defmodule Overlay do
	
	@spec join(bootstrap_ip_address) :: {status, dispatcher_pid}
	def join(bootstrap_ip_address, latlon) do
		spawn &Dispatcher.init(bootstrap_ip_address, latlon)
	end

	def query(dispatcher_pid, latlon) do
		
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

end