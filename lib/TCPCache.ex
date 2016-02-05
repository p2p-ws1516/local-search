defmodule TCPCache do
	
	require Logger

	def new() do
		{:ok, pid} = Agent.start_link fn -> %{} end
		pid
	end

	def put(state, ip, port, socket) do
		Agent.update(state.conn_cache, fn map -> Map.put(map, {ip, port}, {socket, :inactive}) end)
	end

	def remove(state, {ip, port}) do
		Agent.update(state.conn_cache, fn map -> Map.delete(map, {ip, port}) end)
	end

	def use_socket(state, ip, port, acceptor, action ) do
		Agent.update(state.conn_cache, fn map -> (
      Logger.debug 'TCPCache:: current state #{inspect state}'
			result = if (Map.has_key?(map, {ip, port})) do
						{:ok, Map.get(map, {ip, port})}
					 else
					 	opts = [:binary, packet: :line, active: false]
						case :gen_tcp.connect(Network.format_ip(ip), port, opts ) do
							{:ok, socket} -> 
                Logger.debug 'ok'
								map = Map.put(map, {ip, port}, {socket, :inactive})
					 			{:ok, {socket, :inactive}}
							error -> 
                error
					 	end
					end
      Logger.debug 'result #{inspect result}' 
			case result do
				{:ok, {sock, :active}} ->
					Task.start fn -> action.(sock) end
				{:ok, {sock, :inactive}} -> 
					Task.start fn -> acceptor.(sock) end
					unless action == nil do
						Task.start fn -> action.(sock) end				  
					end
					map = Map.put(map, {ip, port}, {sock, :active})
				error -> 
					Logger.warn "#{inspect state.listen_port} Error attempting to connect to #{Network.format({ip, port})} #{inspect error}"
			end
			map) 
	end)
	end

	def close_all(state) do
    Logger.debug 'TCPCache close all sockets'
		Agent.update(state.conn_cache, 
			fn map -> 
				Enum.each(Map.values(map), fn {socket, _task} -> 
          :gen_tcp.close(socket)
        end)
				%{}
				 end)		
	end

end
