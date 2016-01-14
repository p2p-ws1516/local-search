#
# Module for Network I/O (socket handling, IP addresses)
#
defmodule Network do
	
	require Logger	

	@doc ~S"""
	Listen on port and forward all incoming messages to reply_to-address
	"""
	def listen(reply_to, port) do
		{:ok, socket} = :gen_tcp.listen(port,
			[:binary, packet: :line, active: false, reuseaddr: true])
		Logger.debug "Accepting connections on port #{port}"
		loop_acceptor(reply_to, socket)
	end

	@doc ~S"""
	Accepts ingoing TCP connections and sends content to reply_to-address
	"""
	defp loop_acceptor(reply_to, socket) do
		{:ok, client} = :gen_tcp.accept(socket)
		msg = read_msg(client)
		Logger.debug "Got message #{inspect msg}"
		send(reply_to, msg)
		loop_acceptor(reply_to, socket)
	end

	@doc ~S"""
	Sends msg to {ip_address, port} and waits synchronously for reply
	Reply is returned as a tuple {message_type, content} 
	"""
	def send_and_recv_msg({ip_address, port, latlon}, listen_port, msg) do
		Logger.debug "Sending message #{inspect msg} to #{format({ip_address, port})}"
		opts = [:binary, packet: :line, active: false]
		{:ok, socket} = :gen_tcp.connect(format_ip(ip_address), port, opts)
		send_msg(socket, listen_port, msg)
		read_msg(socket)
	end

	def send_msg({ip_address, port, latlon}, listen_port, msg) do
		opts = [:binary, packet: :line, active: false]
		{:ok, socket} = :gen_tcp.connect(format_ip(ip_address), port, opts)
		send_msg(socket, listen_port, msg)
	end

	@doc ~S"""
	Sends message over socket without waiting for a reply
	"""
	def send_msg(socket, reply_port, msg, ttl \\ 7) do
		msg_id = :crypto.hash(:sha256, "whatever") |> Base.encode16
		Logger.debug "Sending message #{inspect msg}"
		{status, line} = case msg do
			{:ping, {lat, lon}} -> 
				JSON.encode(
					[id: msg_id, 
					type: "PING", 
					ttl: ttl, 
					replyport: reply_port, 
					latlon: [lat: lat, lon: lon]])
			{:pong, correlation_id, {lat, lon}} -> 
				JSON.encode(
					[id: msg_id, 
					correlationid: correlation_id, 
					type: "PONG", 
					ttl: ttl, 
					replyport: reply_port,
					latlon: 
					[lat: lat, lon: lon]])
			_ -> raise "Unknown message #{inspect msg}"
		end
		Logger.debug "Sending via TCP #{inspect line}"
		opts = [:binary, packet: :line, active: false]
		:gen_tcp.send(socket, line <> "\r\n")
	end

	@doc ~S"""
	Reads one line from socket and converts it to {message_type, content} 
	"""
	def read_msg(socket) do
		{:ok, data} = :gen_tcp.recv(socket, 0)
		{status, msg} = JSON.decode(data)
		Logger.debug "Got via TCP #{inspect msg}"
		{:ok, {address, _}} = :inet.peername(socket)
		case msg["type"] do
			"PING" ->
				{:ping, msg["id"], {address, msg["replyport"], {msg["latlon"]["lat"], msg["latlon"]["lon"]}}, []}
			"PONG" ->
				{:pong, msg["id"], {address, msg["replyport"], {msg["latlon"]["lat"], msg["latlon"]["lon"]}}}
			msg -> 
				Logger.error "Unexpected network message: [\n#{data}]"
				{:error, :unknown_command}
		end
	end

	def format({ip, port, {lat, lon}}) do
		"#{format_ip(ip)}:#{port}@#{lat},#{lon}"		
	end

	def format({ip, port}) do
		"#{format_ip(ip)}:#{port}"		
	end

	def format_ip({ip1, ip2, ip3, ip4}) do
		to_char_list "#{ip1}.#{ip2}.#{ip3}.#{ip4}"
	end

	def parse_ip(ip) do
		{:ok, tuple} = :inet.parse_ipv4_address(to_char_list(ip))
		tuple
	end
	
end