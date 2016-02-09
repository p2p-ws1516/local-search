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
    state = Map.put( state, :id, generate_id(state) )
    state = Map.put( state, :links, HashSet.new )
    state = Map.put( state, :pending_links, HashSet.new )
    state = Map.put( state, :mymessages, MessageStore.empty )
    state = Map.put( state, :othermessages, MessageStore.empty )
    state = Map.put( state, :status, :init)
    state = Map.put( state, :inventory, [])
    state = Map.put( state, :conn_cache, TCPCache.new)
    
    WebLog.log( "boot", state )

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

    unless( Map.has_key?(state, :bootstrap) and not Enum.empty?(state[:bootstrap])) do
      Logger.info "Initial node in overlay at #{format_latlon(state.location)}\n"
    else
      Logger.info "Joining overlay using bootstrap node #{Network.format(hd(state.bootstrap))} at #{format_latlon(state.location)}\n"
      Task.start_link fn -> Joining.join(this, state, state.bootstrap) end
    end
    
    :timer.apply_after(state.config[:startuptime], GenServer, :cast, [self, {:startup_finished}])
    :timer.apply_after(state.config[:startuptime] + state.config[:refreshtime], GenServer, :cast, [self, {:refresh}])

    {:ok, state }
  end

  def add_item(peer_pid, item) do
    GenServer.call(peer_pid, {:add_item, item})
  end
  
  def get_items(peer_pid) do
    GenServer.call(peer_pid, {:get_items});
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
    # WebLog.log( "refresh", state )
    {:noreply, state}
  end

  def handle_cast( { :ping, msg_id, from_link, source_link, msg_props}, state) do
    this = self()
    Task.start_link fn -> Joining.handle_join(this, msg_id, from_link, source_link, state, msg_props) end
    {:noreply, state}
  end

  def handle_cast( { :pong, correlation_id, {id, ip, port, latlon}, msg_props}, state) do
      this = self
      cond do
        MessageStore.is_own_message(state, correlation_id) ->
          state = add_pending_link(state, {id, ip, port, latlon})
        MessageStore.is_other_message(state, correlation_id) ->
          issuer = MessageStore.get_other_message(state, correlation_id)
          Joining.reply(this, correlation_id, issuer, {id, ip, port, latlon}, msg_props, state)
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
    Logger.info "#{inspect self}, #{inspect state.listen_port}: Link is broken #{inspect link} because of #{inspect error}\n"
    state = Map.update!(state, :links, fn links -> 
      Enum.into(Enum.filter(links, fn {_, ip, port, _} -> {ip, port} != link end), HashSet.new) 
    end)
    TCPCache.remove(state, link)
    Logger.debug "#{inspect state.listen_port} Current list of links:\n#{format_links(state)}"
    WebLog.log( "refresh", state )
    {:noreply, state}
  end

  def handle_cast( { :startup_finished }, state) do
      Logger.debug 'state #{inspect state}' 
      state = Joining.select_links(state)
      Joining.announce_join(self, state)
      state = Map.put(state, :status, :ready)
      
      Logger.info (
        "#{inspect self} at port #{inspect state.listen_port} finished exploring overlay\n"<>
        "Links:\n#{format_links(state)}\n")
      {:noreply, state}
  end

  def handle_cast( { :refresh }, state) do
    WebLog.log( "refresh", state )
    if ( Set.size(state.links) < state.config[:maxlinks] and Map.has_key?(state, :bootstrap) ) do
      state = Map.put(state, :status, :init)
      init_links = if Enum.empty?(state.links) do state.bootstrap else Enum.map(state.links, fn {_, ip, port, _} -> {ip, port} end) end
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
  
   def handle_call( { :get_items }, _from, state) do
    {:reply, state.inventory, state }
   end
  


  def handle_call( { :get_links }, _from, state ) do 
    { :reply, Enum.map(sort_links(state.links), fn { _, ip, port, latlon } -> {ip, port, latlon} end), state }
  end

  def handle_call( { :leave }, _from, state ) do
    supervisor = state.supervisor
    
    WebLog.log( "leave", state )
    Logger.info "#{inspect self} at port #{inspect state.listen_port} shutting down\n"
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
    File.write "log.log", "#{inspect anything}\n"
    { :stop, anything, state}
  end

  defp add_link(state, link) do
    if not Set.member?(state.links, link) do
      Logger.debug "#{inspect self()} listening at #{state.listen_port} got a new link #{inspect link}"
      state = Map.update!(state, :links, fn links -> Set.put(links, link) end)
      WebLog.log( "refresh", state )
      state
    else
      state
    end
  end 

  defp add_pending_link(state, link) do
    if state.status == :init and not Enum.any?(state.links, fn {id, _, _, _} -> id == elem(link, 0) end) do
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
    "#{sort_links(state.links) |> Enum.map(fn l -> "\t" <> to_string(Network.format(l)) end) |> Enum.join("\n")}"
  end

  defp sort_links(links) do
    Enum.sort(links, fn ({_id1, ip1, _port1, latlon1}, {_id2, ip2, _port2, latlon2}) -> {ip1, latlon1} <= {ip2, latlon2} end)
  end

  defp generate_id(state) do
    :crypto.hash(:sha256, 
      "#{inspect :inet.getifaddrs}#{inspect :calendar.universal_time()}#{inspect state.listen_port}#{inspect state.location}") 
      |> Base.encode16
  end

end
