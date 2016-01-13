defmodule Main do

	def main(args) do
		{port, init} = args |> parse_args
		bootstrap_ip = {127, 0, 0, 1}
		bootstrap_port = 9999
		latlon = {10.123123123, 98.123435353}
		Overlay.join({bootstrap_ip, bootstrap_port}, latlon, port, init)
    Agent.start_link fn -> CLI.repl end
	end
  
	defp parse_args(args) do
		case OptionParser.parse(args, switches: [init: :boolean]) do
			{[port: port, init: init], _, _} -> {elem(Integer.parse(port), 0), init}
			{[port: port], _, _} -> {elem(Integer.parse(port), 0), false}		
		end
	end

end
