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
    state = Map.put( state, :conn_cache, TCPCache.new)

    import Supervisor.Spec

    children = [
      supervisor(Task.Supervisor, []),
      worker(Task, 
        [Network, :listen, [self, state]], 
        id: :listener,
        restart: :transient)
    ]

    opts = [strategy: :one_for_one ]

    {_, suppid} = Supervisor.start_link(children, opts)
    state = Map.put(state, :supervisor, suppid)

    this = self

    unless( Map.has_key?( state, :bootstrap) ) do
      Logger.info "Initial node in overlay at #{format_latlon(state.location)}"
    else
      Logger.info "Joining overlay using bootstrap node #{Network.format(hd(state.bootstrap))} at #{format_latlon(state.location)}"
      Task.start_link fn -> Joining.join(this, state, state.bootstrap) end
    end
    
    :timer.apply_after(state.config[:startuptime], GenServer, :cast, [self, {:startup_finished}])
    :timer.apply_after(state.config[:startuptime] + state.config[:refreshtime], GenServer, :cast, [self, {:refresh}])

    {:ok, state }
  end

  def add_item(peer_pid, item) do
    GenServer.call(peer_pid, {:add_item, item})
  end

  #
  # possible opts:
  #   radius (int, km)
  #
  def query(peer_pid, query, opts, reply_to ) do
    GenServer.cast(peer_pid, {:myquery, {query, opts}, reply_to})
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

  def handle_cast( { :newlink, link }, state ) do
    state = add_link(state, link)
    {:noreply, state}
  end

  def handle_cast( { :ping, msg_id, from_link, source_link, msg_props}, state) do
    this = self()
    Task.start_link fn -> Joining.handle_join(this, msg_id, from_link, source_link, state, msg_props) end
    {:noreply, state}
  end

  def handle_cast( { :pong, correlation_id, {ip, port, latlon}, msg_props}, state) do
      this = self
      cond do
        MessageStore.is_own_message(state, correlation_id) ->
          state = add_pending_link(state, {ip, port, latlon})
        MessageStore.is_other_message(state, correlation_id) ->
          issuer = MessageStore.get_other_message(state, correlation_id)
          Joining.reply(this, correlation_id, issuer, {ip, port, latlon}, msg_props, state)
        true ->
          Logger.warn "Unexpected pong referring to #{inspect correlation_id}"
      end
      {:noreply, state}
  end

  def handle_cast( { :myquery, {query, opts}, reply_to }, state) do
    this = self()
    Task.start_link fn -> Query.issue(this, reply_to, {query, opts}, state) end
    {:noreply, state}
  end

  def handle_cast( { :query, msg_id, from_link, query, msg_props }, state) do
    this = self()
    Task.start_link fn -> Query.handle_query(this, msg_id, from_link, query, msg_props, state) end
    {:noreply, state}
  end

  def handle_cast( { :query_hit, correlation_id, query, owner, msg_props }, state) do
     this = self
     cond do
        MessageStore.is_own_message(state, correlation_id) ->
          reply_to = MessageStore.get_own_message(state, correlation_id)
          send(reply_to, {:query_hit, query, owner })
        MessageStore.is_other_message(state, correlation_id) ->
          issuer = MessageStore.get_other_message(state, correlation_id)
          Task.start_link fn -> Query.reply(this, correlation_id, issuer, query, owner, msg_props, state) end
        true ->
          Logger.warn "Unexpected query_hit referring to #{inspect correlation_id}"
      end
      {:noreply, state}
  end

  def handle_cast( {:brokenlink, link, error }, state ) do 
    Logger.info "#{inspect self}, #{inspect state.listen_port}: Link is broken #{inspect link} because of #{inspect error}"
    state = Map.update!(state, :links, fn links -> 
      Enum.into(Enum.filter(links, fn {ip, port, _} -> {ip, port} != link end), HashSet.new) 
    end)
    Logger.debug "#{inspect state.listen_port} Current list of links:\n#{format_links(state)}"
    {:noreply, state}
  end

  def handle_cast( { :startup_finished }, state) do
      Logger.debug 'state #{inspect state}' 
      state = Joining.select_links(state)
      Joining.announce_join(self, state)
      state = Map.put(state, :status, :ready)
      Logger.info (
        "#{inspect self} at port #{inspect state.listen_port} finished startup\n"<>
        "Links:\n#{format_links(state)}")
      {:noreply, state}
  end

  def handle_cast( { :refresh }, state) do
    if ( Set.size(state.links) < state.config[:maxlinks] and Map.has_key?(state, :bootstrap) ) do
      state = Map.put(state, :status, :init)
      init_links = if Enum.empty?(state.links) do state.bootstrap else Enum.map(state.links, fn {ip, port, _} -> {ip, port} end) end
      this = self()
      Task.start_link fn -> Joining.join(this, state, init_links) end
      :timer.apply_after(state.config[:startuptime], GenServer, :cast, [self, {:startup_finished}])
    end
    :timer.apply_after(state.config[:refreshtime], GenServer, :cast, [self, {:refresh}])
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
    Logger.info "#{inspect self} at port #{inspect state.listen_port} shutting down"
    Process.exit(supervisor, :normal)
    TCPCache.close_all(state)
    { :stop, :normal, :ok, state}
  end

  ## handlers for classical Erlang messages

  def handle_info({:EXIT, _pid, :normal }, state ) do 
    {:noreply, state}
  end

  def handle_info( {:DOWN, _, _, _, :normal}, state ) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _, _, _, {:brokenlink, link, error}}, state) do
    Peer.link_broken(self, link, error)
     {:noreply, state}
  end

  def handle_info({:EXIT, _pid, {:brokenlink, link, error}}, state) do
    Peer.link_broken(self, link, error)
     {:noreply, state}
  end

  def handle_info( anything, state ) do
    Logger.info inspect anything
    { :stop, anything, state}
  end

  defp add_link(state, link) do
    if not Set.member?(state.links, link) do
      Logger.debug "#{inspect self()} listening at #{state.listen_port} got a new link #{inspect link}"
      Map.update!(state, :links, fn links -> Set.put(links, link) end)
    else
      state
    end
  end 

  defp add_pending_link(state, link) do
    if state.status == :init and not Set.member?(state.links, link) do
      Logger.debug "#{inspect self()} listening at #{state.listen_port} got a new PENDING link #{inspect link}"
      Map.update!(state, :pending_links, fn links -> Set.put(links, link) end)
    else
      state
    end
  end

  defp format_latlon({lat, lon}) do
    "lat: #{lat}, lon: #{lon}"
  end

  defp format_links(state) do
    "#{Enum.sort(state.links) |> Enum.map(fn l -> "\t" <> to_string(Network.format(l)) end) |> Enum.join("\n")}"
  end

end
