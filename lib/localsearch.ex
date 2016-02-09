defmodule Main do

	def main(args) do
		{port, init, bootstrap_ip, bootstrap_port, latlon, log_ip, log_port} = args |> parse_args
    config = Application.get_all_env :localsearch
		{:ok, pid} = if init do
      		Peer.join(%{
	      	location: latlon,
	        listen_port: port,
	        config: config,
	        bootstrap: [],
	        log: {log_ip, log_port}
	      }) 
	    else
	      Peer.join(%{
	        location: latlon,
	        listen_port: port,
	        config: config,
	        bootstrap: [ { bootstrap_ip,bootstrap_port } ],
	        log: {log_ip, log_port}
	      }) 
    	end
    {:ok, cli} = CLI.start_link()
    CLI.repl( cli, pid )
	end
  defp loop() do
    receive do
      _ -> 
        IO.puts "nothing"
        loop();
    end
    loop();
  end
  
	defp parse_args(args) do
		
		default_bootstrap_ip = {127, 0, 0, 1}
		default_bootstrap_port = 9999
    :random.seed(:os.timestamp) 
		# default_latlon = {10.123123123, 98.123435353}
		default_latlon = {:random.uniform*160-80, :random.uniform*160-80 }
		case OptionParser.parse(args, switches: [init: :boolean]) do
			{[
				port: port, 
				init: init,
				lat: lat,
				lon: lon], 
				_, _} -> 
				{elem(Integer.parse(port), 0), init, nil, nil, {elem(Float.parse(lat), 0), elem(Float.parse(lon), 0)}, nil, nil}
			{[
				port: port, 
				init: init,
				lat: lat,
				lon: lon,
				lip: log_ip,
				lport: log_port], 
				_, _} -> 
				{elem(Integer.parse(port), 0), init, 
					nil, nil, {elem(Float.parse(lat), 0), elem(Float.parse(lon), 0)}, Network.parse_ip(log_ip), elem(Integer.parse(log_port), 0)}
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
				{elem(Float.parse(lat), 0), elem(Float.parse(lon), 0)}, nil, nil}
			{[	
				port: port, 
				bip: bip, 
				bport: bport, 
				lat: lat, 
				lon: lon,
				lip: log_ip,
				lport: log_port], 
				_, _} ->
				bootstrap_ip = Network.parse_ip(bip)
				{bootstrap_port, _} = Integer.parse(bport)
				{elem(Integer.parse(port), 0), 
				false, 
				bootstrap_ip, 
				bootstrap_port, 
				{elem(Float.parse(lat), 0), elem(Float.parse(lon), 0)},
				Network.parse_ip(log_ip),
				elem(Integer.parse(log_port), 0) }
		end
	end

end
