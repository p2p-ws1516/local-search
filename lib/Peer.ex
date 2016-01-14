# central event dispatcher
# 
# all requests should be served asynchronously
#
# 
defmodule Peer do
  use GenServer

  require Logger
  

  @doc """
  Starts the Peer.
  """
  def join( state ) do
    GenServer.start_link(__MODULE__, state, [])
  end

  def init( state ) do
    this = self
    unless( Map.has_key?( state, :links ) ) do
      Logger.info "Initial node in overlay at #{format_latlon(state.location)}"
      state = Map.put( state, :links, [] )
    else
      IO.puts "--- #{inspect hd(state.links)}"
      Logger.info "Joining overlay using bootstrap node #{Network.format(hd(state.links))} at #{format_latlon(state.location)}"
      spawn_link fn -> Joining.join(this, hd(state.links), state.location) end
    end
    
    spawn_link fn -> Network.listen(this, state.listen_port) end
    {:ok, state }
  end

  def get_links( pid ) do
    GenServer.call(pid, { :get_links })
    
    # send(peer_pid, {:get_links, self()})
    # receive do
    #   {:ok, links} -> links
    # end
  end
  
  def handle_call( { :get_links }, _from, state ) do 
    { :reply, state.links, state }
  end
  
  def handle_info( anything, state ) do 
    IO.puts "---d-d-d-d #{inspect anything}"
    
     {:noreply, state}
  end

  defp format_latlon({lat, lon}) do
    "lat: #{lat}, lon: #{lon}"
  end
  
  ######### TODO: refactor to genserver

  def query(peer_pid, latlon, query) do

  end

  def leave(peer_pid) do
    send(peer_pid, {:leave, self()})
    receive do
      {:ok} ->
        Logger.info "Successfully finished"
      msg ->
        Logger.info "Leaving the network failed with #{msg}"
    end
  end
  

  #
  # links is a set of {id, socket, latlon}-tuples
  # latlon is a {latitude, longitude}-pair
  # data is the collection of data elements held by this peer
  #
  # Do not block in the event handler of this function!
  #
  # defp loop(links, location, data, listen_port) do
  defp loop( state ) do
    this = self
    receive do
      {:joined, links} ->
        Logger.info "Successfully joined overlay"
        Logger.info "Current links:\n[#{Enum.join(Enum.map(links, &inspect/1), "\n")}]"
        state_ = Map.put( state, :links, links )
        loop( state_ )

      {:newlink, link} ->
        state_ = Map.update!( state, :links, fn links -> [ link | links ] end );
        loop( state_ )

      {:request_join, socket, other_latlon, req_options} ->
        spawn_link fn -> Joining.handle_join(this, socket, state.location, state.listen_port, other_latlon, req_options) end
        loop( state )

      {:leave, requestor} ->
        spawn fn -> leave(requestor, state.links) end

      {:query, requestor, other_latlon, query, req_options} ->
        spawn_link fn -> Query.handle(requestor, state.links, state.location, query) end
        loop( state )
        
      # {:get_links, requestor} ->
      #   send(requestor, {:ok, state.links })
      #   loop( state )
        
      msg ->
        IO.puts "Invalid message #{inspect msg}"
        loop( state )
    end
  end

  defp leave(requestor, links) do
    # for each link, tell that you leave
    # close collections
    # return to sender
    send(requestor, {:ok, self()})
  end

end
