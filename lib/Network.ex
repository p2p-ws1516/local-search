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
		GenServer.cast(reply_to, msg)
		loop_acceptor(reply_to, socket)
	end

	@doc ~S"""
	Sends msg to {ip_address, port} and waits synchronously for reply
	Reply is returned as a tuple {message_type, content} 
	"""
	def send_and_recv_msg({ip_address, port, latlon}, listen_port, my_latlon, msg) do
		opts = [:binary, packet: :line, active: false, reuseaddr: :true]
		{:ok, socket} = :gen_tcp.connect(format_ip(ip_address), port, opts)
		send_msg(socket, listen_port, my_latlon, msg)
		read_msg(socket)
	end

	@doc ~S"""
	Sends message to specified address without waitung for a reply and returns message id
	"""
	def send_msg({ip_address, port, latlon}, listen_port, my_latlon, msg) do
		opts = [:binary, packet: :line, active: false, reuseaddr: :true]
		case :gen_tcp.connect(format_ip(ip_address), port, opts) do
			{:ok, socket} -> send_msg(socket, listen_port, my_latlon, msg)
			error -> raise "Error #{inspect error} from #{inspect self}, at port #{listen_port} connecting to #{Network.format({ip_address, port, latlon})}" 
		end
	end

	@doc ~S"""
	Sends message over socket without waiting for a reply and returns the message id
	"""
	def send_msg(socket, reply_port, my_latlon, msg, ttl \\ 7) do
		msg_id = :crypto.hash(:sha256, 
			"#{inspect msg}#{inspect :inet.peername(socket)}#{inspect :calendar.universal_time()}") 
			|> Base.encode16
		Logger.debug "#{reply_port} Sending message #{inspect msg} to #{inspect :inet.peername(socket)}"
		{status, line} = case msg do
			{:ping, correlation_id, source_link} -> 
				JSON.encode(
					[id: msg_id, 
					type: :ping, 
					ttl: ttl,
					correlationid: correlation_id, 
					replyport: reply_port,
					latlon: my_latlon,
					sourcelink: source_link])
			{:pong, correlation_id, new_link} -> 
				JSON.encode(
					[id: msg_id, 
					correlationid: correlation_id, 
					type: :pong, 
					ttl: ttl, 
					replyport: reply_port,
					link: new_link])
			_ -> raise "Unknown message #{inspect msg}"
		end
		Logger.debug "Sending via TCP #{inspect line}"
		opts = [:binary, packet: :line, active: false]
		:gen_tcp.send(socket, line <> "\r\n")
		msg_id
	end

	@doc ~S"""
	Reads one line from socket and converts it to {message_type, content} 
	"""
	def read_msg(socket) do
		{:ok, data} = :gen_tcp.recv(socket, 0)
		{status, msg} = JSON.decode(data)
		Logger.debug "Got via TCP #{inspect msg}"
		{:ok, {address, _}} = :inet.peername(socket)
		case String.to_atom(msg["type"]) do
			:ping ->
				correlation_id = msg["correlationid"]
				if (correlation_id == nil) do correlation_id = msg["id"] end
				[source_ip, source_port, source_latlon] = msg["sourcelink"]
				if (source_ip == nil) do # ping from direct neighbour, doesnt know his own IP
					source_ip = address
					source_port = msg["replyport"]
				else
					source_ip = List.to_tuple(source_ip)
				end
				source_latlon = List.to_tuple(source_latlon) 
				{:ping, 
					correlation_id, 
					{address, msg["replyport"], List.to_tuple(msg["latlon"])},
					{source_ip, source_port, source_latlon},
					[]}
			:pong ->
				[ip, port, latlon] = msg["link"]
				if (ip == nil) do # pong is direct neighbour, doesnt know his own IP
					ip = address
					port = msg["replyport"]
				else
					ip = List.to_tuple(ip)
				end
				latlon = List.to_tuple(latlon)
				{:pong, msg["correlationid"], {ip, port, latlon}}
			msg -> 
				Logger.error "Unexpected network message: [\n#{data}]"
				{:error, :unknown_command}
		end
	end

	@doc ~S"""
	Extracts the lat/lon from a link tuple
	"""
	def latlon({ip, port, latlon}) do
		latlon
	end

	@doc ~S"""
  	Formats IP, port and latlon tuple to string.

  	## Examples

      iex> Network.format({{127, 0, 0, 1}, 8080, {12.111115555, 13.4444499999}})
      '127.0.0.1:8080@12.111115555,13.4444499999'

  	"""
	def format({ip, port, {lat, lon}}) do
		to_char_list "#{format_ip(ip)}:#{port}@#{lat},#{lon}"		
	end

	@doc ~S"""
  	Formats IP-and-port-tuple to string.

  	## Examples

      iex> Network.format({{127, 0, 0, 1}, 8080})
      '127.0.0.1:8080'

  	"""
	def format({ip, port}) do
		to_char_list "#{format_ip(ip)}:#{port}"		
	end

	@doc ~S"""
  	Formats IP-tuple to string.

  	## Examples

      iex> Network.format_ip({127, 0, 0, 1})
      '127.0.0.1'

  	"""
	def format_ip({ip1, ip2, ip3, ip4}) do
		to_char_list "#{ip1}.#{ip2}.#{ip3}.#{ip4}"
	end

	@doc ~S"""
  	Parses the given simple IP string into a tuple.

  	## Examples

      iex> Network.parse_ip("1.2.3.4")
      {1,2,3,4}

  	"""
	def parse_ip(ip) do
		{:ok, tuple} = :inet.parse_ipv4_address(to_char_list(ip))
		tuple
	end
	
end