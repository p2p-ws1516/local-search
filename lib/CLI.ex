# Command Line Interface

defmodule CLI do
  
  def repl(dispatcher_pid) do
    input = IO.gets "➤  "
    call = String.split input
    case call do
      ["help"] -> help
      ["links", "get"] -> linksGet( dispatcher_pid )
      ["items", "get"] -> itemsGet  
      ["items", "add", name] -> itemsAdd name
      ["find", name, "in", km] -> query name, km
      ["leave"] -> leave
      _ -> help
    end
    unless call==["leave"] do repl(dispatcher_pid) end
  end
  
  defp help() do
    IO.puts "LocalSearch p2p network

    Usage:
    
      links get               prints out all current links
      
      help                    prints out this help message
      items get               list all items you manage
      items add <name>        add <name> to your list
      find <name> in <km>     find <name> in your local network in the radius of <km> kilometers
      leave                   leave the network
    "
  end
  
  defp linksGet( peer ) do
    # links = Enum.map(Peer.get_links( peer ), {{i1,i2,i3,i4}, port, { lon, lat }} -> "#{i1}.#{i2}");
    IO.puts 'get links #{ inspect Peer.get_links( peer ) }'
  end
  
  defp itemsGet() do
    IO.puts "nothing inside"
  end
  
  defp query( name, km ) do
    IO.puts "looking for #{name} in #{km}km radius..."
  end

  defp itemsAdd ( name ) do 
    IO.puts "adding #{name} to set"
  end
  
  defp leave() do
    IO.puts "bye bye ..."
  end

end

