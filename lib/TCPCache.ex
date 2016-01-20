defmodule TCPCache do
	
	require Logger

	def new() do
		{:ok, pid} = Agent.start_link fn -> %{} end
		pid
	end

	def put(state, ip, port, socket) do
		Agent.update(state.conn_cache, fn map -> Map.put(map, {ip, port}, {socket, :inactive}) end)		
	end

	def use_socket(_peer, state, ip, port, action, replace_task \\ true ) do
		Agent.update(state.conn_cache, fn map -> (
			result = if (Map.has_key?(map, {ip, port})) do
						{:ok, Map.get(map, {ip, port})}
					 else
					 	opts = [:binary, packet: :line, active: false, reuseaddr: true, port: state.send_port]
						case :gen_tcp.connect(Network.format_ip(ip), port, opts) do
							{:ok, socket} -> 
								map = Map.put(map, {ip, port}, {socket, :inactive})
					 			{:ok, {socket, :inactive}}
							error -> error
					 	end
					 end
			case result do
				{:ok, {sock, :inactive}} -> 
					map = Map.put(map, {ip, port}, {sock, :active})
					Task.start fn -> action.(sock) end 
				{:ok, {sock, :active}} when replace_task ->
					Task.start fn -> action.(sock) end
				{:ok, {_sock, :active}} -> :ok
				error -> 
					Logger.warn "Error attempting to connect to #{Network.format({ip, port})} #{inspect error}"
			end
			map
		) end)
	end

	def close_all(state) do
		Agent.update(state.conn_cache, 
			fn map -> 
				Enum.each(Map.values(map), fn {socket, _task} -> :gen_tcp.close(socket) end)
				%{}
				 end)		
	end

end