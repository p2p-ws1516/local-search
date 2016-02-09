# Command Line Interface

defmodule CLI do
  use GenServer

  require Logger
  
  def start_link( ) do
    GenServer.start_link(__MODULE__, :ok, [])
  end
  
  def repl(cli, dispatcher_pid) do
    input = IO.gets "➤  "
    call = String.split input
    case call do
      ["help"] -> help
      ["links", "get"] -> linksGet( dispatcher_pid )
      ["items", "get"] -> itemsGet( dispatcher_pid )
      ["items", "add", name] -> itemsAdd( dispatcher_pid, name )
      ["find", name, "in", km] -> query cli, dispatcher_pid, name, km
      ["leave"] -> leave dispatcher_pid
      _ -> help
    end
    unless call==["leave"] do CLI.repl( cli, dispatcher_pid ) end
  end
  
  defp help() do
    IO.puts "LocalSearch p2p network

    Usage:
    
      help                    prints out this help message
      links get               prints out all current links
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
  
  defp itemsGet( peer ) do
    IO.puts '#{ inspect Peer.get_items( peer ) }'
  end
  
  defp query( this, peer, name, km ) do
    Peer.query( peer, name, [radius: elem(Integer.parse(km),0)], this )
    IO.puts "looking for #{name}"
  end

  defp itemsAdd( peer, name ) do 
    Peer.add_item( peer, name )
    IO.puts "#{name} added to set"
  end
  
  defp leave( peer ) do
    Peer.leave( peer )
    IO.puts "bye bye ..."
  end
  
  def handle_info({ :query_hit, query, owner }, state) do
    Logger.info 'found #{inspect query} at #{inspect owner}\n' 
    {:noreply, state}
  end

end
#
#
#
# defmodule Observer do
#   use GenServer
#   require Logger
#   
#   def run( ) do
#     GenServer.start_link(__MODULE__, %{}, [])
#   end
#
#   def init( state ) do
#     {:ok, %{}}
#   end
#   
#   # def handle_info({:query_hit, what, _from }, state ) do 
#   #   Logger.debug 'hit'
#   #   {:noreply, state}
#   # end
#   
#   def handle_call(_msg, state) do
#     Logger.debug '_msg #{inspect _msg}' 
#     {:noreply, state}
#   end
#   
# end
