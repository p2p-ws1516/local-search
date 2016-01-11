defmodule Network do
	
	require Logger	

	def listen(dispatcher, port) do
		{:ok, socket} = :gen_tcp.listen(port,
			[:binary, packet: :line, active: false, reuseaddr: true])
		Logger.info "Accepting connections on port #{port}"
		loop_acceptor(dispatcher, socket)
	end

	defp loop_acceptor(dispatcher, socket) do
		{:ok, client} = :gen_tcp.accept(socket)
		msg = read_line(client)
		Logger.debug "Got message #{inspect msg}"
		send(dispatcher, msg)
		loop_acceptor(dispatcher, socket)
	end

	def read_line(socket) do
		{:ok, data} = :gen_tcp.recv(socket, 0)
		case String.split(data) do
			["REQUESTJOIN", lat, lon] -> 
				{:request_join, socket, {lat, lon}, []}
			["GRANTJOIN" | links ] -> 
				{:joined, links}
			msg -> 
				Logger.error "Unexpected network message: [\n#{data}]"
				{:error, :unknown_command}
		end
	end

	def send_and_recv_msg({ip_address, port}, msg) do
		Logger.debug "Sending message #{inspect msg} to #{format({ip_address, port})}"
		opts = [:binary, packet: :line, active: false]
		{:ok, socket} = :gen_tcp.connect('127.0.0.1', port, opts)
		line = case msg do
			{:request_join, {lat, lon}} -> "REQUESTJOIN #{lat} #{lon}"
			_ -> raise "Unknown message #{inspect msg}"
		end
		ok = :gen_tcp.send(socket, line <> "\r\n")
		read_line(socket)
	end

	def send_msg(socket, msg) do
		Logger.debug "Sending message #{inspect msg}"
		line = case msg do
			{:grant_join, links} -> "GRANTJOIN #{Enum.join(Enum.map(links, &format/1), ", ")}"
			_ -> raise "Unknown message #{inspect msg}"
		end
		:gen_tcp.send(socket, line <> "\r\n")
	end


	def format({ip, port, {lat, lon}}) do
		"#{format_ip(ip)}:#{port}@#{lat},#{lon}"		
	end

	def format({ip, port}) do
		"#{format_ip(ip)}:#{port}"		
	end

	def format_ip({ip1, ip2, ip3, ip4}) do
		"#{ip1}.#{ip2}.#{ip3}.#{ip4}"
	end

end