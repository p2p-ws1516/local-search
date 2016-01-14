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
		Logger.debug "Got message #{inspect msg} #{inspect reply_to}"
		send(reply_to, msg)
		loop_acceptor(reply_to, socket)
	end

	@doc ~S"""
	Sends msg to {ip_address, port} and waits synchronously for reply
	Reply is returned as a tuple {message_type, content} 
	"""
	def send_and_recv_msg({ip_address, port}, msg) do
		Logger.debug "Sending message #{inspect msg} to #{format({ip_address, port})}"
		opts = [:binary, packet: :line, active: false]
		{:ok, socket} = :gen_tcp.connect('127.0.0.1', port, opts)
		send_msg(socket, msg)
		read_msg(socket)
	end

	@doc ~S"""
	Sends message over already established socket without waiting for a reply
	"""
	def send_msg(socket, msg, ttl \\ 7) do
		msg_id = :crypto.hash(:sha256, "whatever") |> Base.encode16
		Logger.debug "Sending message #{inspect msg}"
		{status, line} = case msg do
			{:request_join, {lat, lon}} -> 
				JSON.encode([id: msg_id, type: "PING", ttl: ttl, latlon: [lat: lat, lon: lon]])
			{:grant_join, links} -> 
				JSON.encode([id: msg_id, type: "PONG", ttl: ttl, links: links])
			_ -> raise "Unknown message #{inspect msg}"
		end
		Logger.debug "Sending via TCP #{inspect line}"
		:gen_tcp.send(socket, line <> "\r\n")
	end

	@doc ~S"""
	Reads one line from socket and converts it to {message_type, content} 
	"""
	def read_msg(socket) do
		{:ok, data} = :gen_tcp.recv(socket, 0)
		{status, msg} = JSON.decode(data)
		Logger.debug "Got via TCP #{inspect msg}"
		case msg["type"] do
			"PING" ->
				{:request_join, socket, {msg["latlon"]["lat"], msg["latlon"]["lon"]}, []}
			"PONG" ->
				{:joined, msg["links"]}
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
		"#{ip1}.#{ip2}.#{ip3}.#{ip4}"
	end

	def parse_ip(ip) do
		{:ok, tuple} = :inet.parse_ipv4_address(to_char_list(ip))
		tuple
	end
	
end
