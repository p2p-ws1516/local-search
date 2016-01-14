defmodule Main do

	def main(args) do
		{port, init, bootstrap_ip, bootstrap_port, latlon} = args |> parse_args
		dispatcher = Peer.join({bootstrap_ip, bootstrap_port}, latlon, port, init)
    	Agent.start_link fn -> CLI.repl(dispatcher) end
	end
  
	defp parse_args(args) do
		
		default_bootstrap_ip = {127, 0, 0, 1}
		default_bootstrap_port = 9999
		default_latlon = {10.123123123, 98.123435353}
		case OptionParser.parse(args, switches: [init: :boolean]) do
			{[
				port: port, 
				init: init ],
				_, _} -> 
				{elem(Integer.parse(port), 0), init, nil, nil, default_latlon}
			{[
				port: port, 
				init: init,
				lat: lat,
				lon: lon], 
				_, _} -> 
				{elem(Integer.parse(port), 0), init, nil, nil, {Float.parse(lat), Float.parse(lon)}}
			{[	
				port: port, 
				bip: bip, 
				bport: bport, 
				lat: lat, 
				lon: lon ], 
				_, _} ->
				bootstrap_ip = Network.parse_ip(bip)
				{bootstrap_port, _} = Integer.parse(bport)
				{elem(Integer.parse(port), 0), 
				false, 
				bootstrap_ip, 
				bootstrap_port, 
				{elem(Float.parse(lat), 0), 
				elem(Float.parse(lon), 0)}}
			{[
				port: port ], 
				_, _} ->
				{elem(Integer.parse(port), 0), false, default_bootstrap_ip, default_bootstrap_port, default_latlon}		
		end
	end

end
