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
    Process.flag(:trap_exit, true)
    state = Map.put( state, :links, HashSet.new )
    state = Map.put( state, :pending_links, HashSet.new )
    state = Map.put( state, :mymessages, MessageStore.empty )
    state = Map.put( state, :othermessages, MessageStore.empty )
    state = Map.put( state, :status, :init)
    state = Map.put( state, :inventory, [])

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
    {_, suppid} = Supervisor.start_link(children, opts)
    state = Map.put(state, :supervisor, suppid)

    :timer.apply_after(state.config[:startuptime], GenServer, :cast, [self, {:startup_finished}])

    {:ok, state }
  end

  def add_item(peer_pid, item) do
    GenServer.call(peer_pid, {:add_item, item})
  end

  def query(peer_pid, query, reply_to ) do
    GenServer.cast(peer_pid, {:myquery, query, reply_to})
  end

  def leave(peer_pid) do
    GenServer.call(peer_pid, {:leave })
  end

  def suggest_link( pid, link ) do
    GenServer.cast(pid, {:newlink, link })
  end

  def link_broken(pid, link, error) do
    GenServer.cast(pid, {:brokenlink, link, error})
  end

  def get_links( pid ) do
    GenServer.call(pid, { :get_links })
  end

  ## asynchronous casts 

  def handle_cast( { :ping, msg_id, from_link, source_link, msg_props}, state) do
    this = self()
    spawn_link fn -> Joining.handle_join(this, msg_id, from_link, source_link, state, msg_props) end
    {:noreply, state}
  end
  
  def handle_cast( { :newlink, link }, state ) do
    state = add_pending_link(state, link)
    {:noreply, state}
  end

  def handle_cast( { :pong, correlation_id, link, msg_props}, state) do
      cond do
        MessageStore.is_own_message(state, correlation_id) ->
          state = add_pending_link(state, link)
        MessageStore.is_other_message(state, correlation_id) ->
          issuer = MessageStore.get_other_message(state, correlation_id)
          spawn_link fn -> Joining.reply(correlation_id, issuer, link, msg_props, state) end
        true ->
          Logger.warn "Unexpected pong referring to #{inspect correlation_id}"
      end
      {:noreply, state}
  end

  def handle_cast( { :myquery, query, reply_to }, state) do
    this = self()
    spawn_link fn -> Query.issue(this, reply_to, query, state) end
    {:noreply, state}
  end

  def handle_cast( { :query, msg_id, from_link, query, msg_props }, state) do
    this = self()
    spawn_link fn -> Query.handle_query(this, msg_id, from_link, query, msg_props, state) end
    {:noreply, state}
  end

  def handle_cast( { :query_hit, correlation_id, query, owner, msg_props }, state) do
     cond do
        MessageStore.is_own_message(state, correlation_id) ->
          reply_to = MessageStore.get_own_message(state, correlation_id)
          send(reply_to, {:query_hit, query, owner })
        MessageStore.is_other_message(state, correlation_id) ->
          issuer = MessageStore.get_other_message(state, correlation_id)
          spawn_link fn -> Query.reply(correlation_id, issuer, query, owner, msg_props, state) end
        true ->
          Logger.warn "Unexpected query_hit referring to #{inspect correlation_id}"
      end
      {:noreply, state}
  end

  def handle_cast( {:brokenlink, link, error }, state ) do 
    Logger.error "#{inspect self}, #{inspect state.listen_port}: Link is broken #{inspect link} because of #{inspect error}"
    state = Map.update!(state, :links, fn links -> Set.delete(links, link) end)
     {:noreply, state}
  end

  def handle_cast( { :startup_finished }, state) do
      state = Joining.select_links(state)
      state = Map.put(state, :status, :ready)
      Logger.info (
        "#{inspect self} at port #{inspect state.listen_port} finished startup\n"<>
        "Links:\n#{Enum.sort(state.links) |> Enum.map(fn l -> "\t" <> to_string(Network.format(l)) end) |> Enum.join("\n")}")
      {:noreply, state}
  end

  ## synchronous calls

  def handle_call( { :add_item, item }, _from, state) do
    state = Map.update!(state, :inventory, fn items -> [item | items] end)
    {:reply, :ok, state }
  end

  def handle_call( { :get_links }, _from, state ) do 
    { :reply, state.links, state }
  end

  def handle_call( { :leave }, _from, state ) do
    supervisor = state.supervisor
    Process.exit(supervisor, :normal)
    { :stop, :normal, :ok, state}
  end

  ## handlers for classical Erlang messages

  def handle_info( {:EXIT, _pid, :normal }, state ) do 
    {:noreply, state}
  end

  def handle_info({:EXIT, _pid, {:brokenlink, link, error}}, state) do
    Peer.link_broken(self, link, error)
     {:noreply, state}
  end

  def handle_info( anything, state ) do 
    { :stop, anything, state}
  end

  defp add_pending_link(state, link) do
    if Set.size(state.links) < state.config[:maxlinks] and not Set.member?(state.links, link) do
      Logger.debug "#{inspect self()} listening at #{state.listen_port} got a new link #{inspect link}"
      key = if (state.status == :init) do :pending_links else :links end
      state = Map.update!(state, key, fn links -> Set.put(links, link) end)
    end
    state
  end

  defp format_latlon({lat, lon}) do
    "lat: #{lat}, lon: #{lon}"
  end

end
