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

	## Accepts ingoing TCP connections and sends content to reply_to-address
	defp loop_acceptor(reply_to, socket) do
		client = case :gen_tcp.accept(socket) do
			{:ok, client} -> client
			_error -> exit(:shutdown)
		end
		msg = read_msg(client)
		GenServer.cast(reply_to, msg)
		loop_acceptor(reply_to, socket)
	end

	@doc ~S"""
	Generates a new message id, that is returned along with all other parameters
	"""
	def get_msg_id(msg, _config) do
		:crypto.hash(:sha256, 
			"#{inspect msg}#{inspect :inet.getifaddrs}#{inspect :calendar.universal_time()}") 
			|> Base.encode16
	end

	@doc ~S"""
	Sends message to specified address without waitung for a reply and returns message id
	"""
	def send_msg(msg_id, {ip_address, port, latlon}, msg, msg_props, config) do
		if msg_props[:ttl] == 0 or msg_props[:hopcount] >= config[:ttl] do
			nil
		else
			opts = [:binary, packet: :line, active: false, reuseaddr: true]
			socket = case :gen_tcp.connect(Network.format_ip(ip_address), port, opts) do
				{:ok, socket} -> socket
				error -> exit({:brokenlink, {ip_address, port, latlon}, error}) 
			end
			send_impl(msg_id, socket, msg, msg_props)
		end
	end

 	## Sends message over socket without waiting for a reply and returns the message id
	defp send_impl(msg_id, socket, msg, msg_props) do
		Logger.debug "#{msg_props[:replyport]} Sending message #{inspect msg} to #{inspect :inet.peername(socket)}"
		{_status, line} = case msg do
			{:ping, correlation_id, source_link} -> 
				JSON.encode(
					[id: msg_id, 
					type: :ping, 
					correlationid: correlation_id, 
					props: msg_props,
					sourcelink: source_link])
			{:pong, correlation_id, new_link} -> 
				JSON.encode(
					[id: msg_id, 
					correlationid: correlation_id, 
					type: :pong, 
					props: msg_props,
					link: new_link])
			{:query, correlation_id, query } ->
				JSON.encode(
					[id: msg_id, 
					correlationid: correlation_id, 
					type: :query, 
					props: msg_props,
					query: query ])
			{:query_hit, correlation_id, query, owner } ->
				JSON.encode(
					[id: msg_id, 
					correlationid: correlation_id, 
					type: :query_hit, 
					props: msg_props,
					query: query,
					owner: owner ])
			_ -> exit({:unknown_message, msg, msg_props})
		end
		Logger.debug "Sending via TCP #{inspect line}"
		:gen_tcp.send(socket, line <> "\r\n")
		msg_id
	end

	@doc ~S"""
	Reads one line from socket and converts it to {message_type, content} 
	"""
	def read_msg(socket) do
		data = case :gen_tcp.recv(socket, 0) do
			{:ok, data} -> data
			error -> raise error 
		end
		{_status, msg} = JSON.decode(data)
		Logger.debug "Got via TCP #{inspect msg}"
		{:ok, {address, _}} = :inet.peername(socket)
		props = props(msg)
		props = Map.update!(props, :ttl, fn ttl -> ttl - 1 end)
		props = Map.update!(props, :hopcount, fn hc -> hc + 1 end)
		case String.to_atom(msg["type"]) do
			:ping ->
				correlation_id = msg["correlationid"]
				if (correlation_id == nil) do correlation_id = msg["id"] end
				[source_ip, source_port, source_latlon] = msg["sourcelink"]
				if (source_ip == nil) do # ping from direct neighbour, doesnt know his own IP
					source_ip = address
					source_port = props[:replyport]
				else
					source_ip = List.to_tuple(source_ip)
				end
				source_latlon = List.to_tuple(source_latlon) 
				{:ping, 
					correlation_id, 
					{address, props[:replyport], List.to_tuple(props[:latlon])},
					{source_ip, source_port, source_latlon},
					props
				}
			:pong ->
				[ip, port, latlon] = msg["link"]
				if (ip == nil) do # pong is direct neighbour, doesnt know his own IP
					ip = address
					port = props[:replyport]
				else
					ip = List.to_tuple(ip)
				end
				latlon = List.to_tuple(latlon)
				{:pong, 
					msg["correlationid"], 
					{ip, port, latlon},
					props}
			:query ->
				correlation_id = msg["correlationid"]
				if (correlation_id == nil) do correlation_id = msg["id"] end
				{:query, 
					correlation_id, 
					{address, props[:replyport], List.to_tuple(props[:latlon])},
					msg["query"],
					props
				}
			:query_hit ->
				[ip, port, latlon] = msg["owner"]
				if (ip == nil) do # owner is direct neighbour, doesnt know his own IP
					ip = address
					port = props[:replyport]
				else
					ip = List.to_tuple(ip)
				end
				latlon = List.to_tuple(latlon)
				{:query_hit, 
					msg["correlationid"], 
					msg["query"],
					{ip, port, latlon},
					props
				}
			msg -> 
				exit({:unknown_message, msg, props})
		end
	end

	@doc ~S"""
	extracts message properties from JSON message
	"""
	def props(json_msg) do
		for {key, val} <- json_msg["props"], into: %{}, do: {String.to_atom(key), val}
	end

	@doc ~S"""
	resets ttl and hopcount to default
	"""
	def reset_props(props, config) do
		props = Map.put(props, :ttl, config[:ttl])
		props = Map.put(props, :hopcount, 0)
		props
	end

	@doc ~S"""
	Extracts the lat/lon from a link tuple
	"""
	def latlon({_ip, _port, latlon}) do
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