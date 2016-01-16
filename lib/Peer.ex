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
    state = Map.put( state, :links, HashSet.new )
    state = Map.put( state, :mymessages, MessageStore.empty )
    state = Map.put( state, :othermessages, MessageStore.empty )
    
    import Supervisor.Spec

    children = [
      supervisor(Task.Supervisor, []),
      worker(Task, 
        [Network, :listen, [self, state.listen_port]], 
        id: :listener,
        restart: :transient)
    ]

    opts = [strategy: :one_for_one ]

    unless( Map.has_key?( state, :bootstrap) ) do
      Logger.info "Initial node in overlay at #{format_latlon(state.location)}"
    else
      Logger.info "Joining overlay using bootstrap node #{Network.format(hd(state.bootstrap))} at #{format_latlon(state.location)}"
      children = 
        [ worker(Task, 
          [Joining, :join, [self, state, hd(state.bootstrap)]], 
          id: :joining, 
          restart: :transient) | children ]
    end
    {status, suppid} = Supervisor.start_link(children, opts)
    state = Map.put(state, :supervisor, suppid)
    {:ok, state }
  end

  def query(peer_pid, latlon, query) do

  end

  def leave(peer_pid) do
    GenServer.call(peer_pid, {:leave })
  end

  def suggest_link( pid, link ) do
    GenServer.cast(pid, {:newlink, link })
  end

  def get_links( pid ) do
    GenServer.call(pid, { :get_links })
  end

  def handle_cast( { :ping, msg_id, from_link, source_link, msg_props}, state) do
    this = self()
    spawn_link fn -> Joining.handle_join(this, msg_id, from_link, source_link, state, msg_props) end
    {:noreply, state}
  end
  
  def handle_cast( { :newlink, link }, state ) do
    state = add_link(state, link)
    {:noreply, state}
  end

  def handle_cast( { :pong, correlation_id, link, msg_props}, state) do
      cond do
        MessageStore.is_own_message(state, correlation_id) ->
          state = add_link(state, link)
          Logger.info "Current list of links #{inspect Map.get(state, :links)}"
        MessageStore.is_other_message(state, correlation_id) ->
          issuer = MessageStore.get_other_message(state, correlation_id)
          IO.puts inspect issuer
          Joining.reply(correlation_id, issuer, link, state, msg_props)
        true ->
          Logger.warn "Unexpected pong referring to #{inspect correlation_id}"
      end
      {:noreply, state}
  end

  def handle_call( { :get_links }, _from, state ) do 
    { :reply, state.links, state }
  end

  def handle_call( { :leave }, _from, state ) do
    supervisor = state.supervisor
    Process.exit(supervisor, :normal)
    { :stop, :normal, :ok, state}
  end
  
  def handle_info( anything, state ) do 
    IO.puts "---d-d-d-d #{inspect anything}"
    
     {:noreply, state}
  end

  defp add_link(state, link) do
    if Set.size(state.links) < state.config[:maxlinks] and not Set.member?(state.links, link) do
      Logger.debug "#{inspect self()} listening at #{state.listen_port} got a new link #{inspect link}"
      state = Map.update!(state, :links, fn links -> Set.put(links, link) end)
    end
    state
  end

  defp format_latlon({lat, lon}) do
    "lat: #{lat}, lon: #{lon}"
  end

end
