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
    state = Map.put( state, :links, [] )
    
    unless( Map.has_key?( state, :bootstrap) ) do
      Logger.info "Initial node in overlay at #{format_latlon(state.location)}"
    else
      Logger.info "Joining overlay using bootstrap node #{Network.format(hd(state.bootstrap))} at #{format_latlon(state.location)}"
      spawn_link fn -> Joining.join(this, hd(state.bootstrap), state.location, state.listen_port) end
    end
    
    spawn_link fn -> Network.listen(this, state.listen_port) end
    {:ok, state }
  end

  def get_links( pid ) do
    GenServer.call(pid, { :get_links })
  end

  def handle_cast( { :ping, msg_id, from_link, req_options}, state) do
      this = self()
      spawn_link fn -> Joining.handle_join(this, msg_id, from_link, state, req_options) end
      {:noreply, state}
  end
  
  def handle_cast( { :pong, msg_id, link}, state) do
      state = Map.update!(state, :links, fn links -> [link | links] end)
      Logger.info "Current list of links #{inspect Map.get(state, :links)}"
      {:noreply, state}
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

  defp leave(requestor, links) do
    # for each link, tell that you leave
    # close collections
    # return to sender
    send(requestor, {:ok, self()})
  end

end
