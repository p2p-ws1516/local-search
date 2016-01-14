# central event dispatcher
# 
# all requests should be served asynchronously
#
# 
defmodule Peer do

    require Logger

    @doc ~S"""
    Init without obtaining other links (i.e. if peer is the first node)
    """
    def init(latlon, listen_port) do
        this = self
        spawn_link fn -> Network.listen(this, listen_port) end
        loop([], latlon, [], listen_port)
    end

    @doc ~S"""
    Init using the bootstrap_node to get to know other peers
    """
    def init(bootstrap_node, latlon, listen_port) do
        this = self
        spawn_link fn -> Network.listen(this, listen_port) end
        spawn_link fn -> Joining.join(this, bootstrap_node, latlon, listen_port) end
        loop([], latlon, [], listen_port)
    end
    
    def join(bootstrap_node, latlon, listen_port, init) do
        if init do
            Logger.info "Initial node in overlay at #{format_latlon(latlon)}"
            spawn_link fn -> Peer.init(latlon, listen_port) end
        else 
            Logger.info "Joining overlay using bootstrap node #{Network.format(bootstrap_node)} at #{format_latlon(latlon)}"
            spawn_link fn -> Peer.init(bootstrap_node, latlon, listen_port) end
        end
    end

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
  
  def get_links( peer_pid ) do
    send(peer_pid, {:get_links, self()})
    receive do
      {:ok, links} -> links
    end
  end

    defp format_latlon({lat, lon}) do
        "lat: #{lat}, lon: #{lon}"
    end

    #
    # links is a set of {id, socket, latlon}-tuples
    # latlon is a {latitude, longitude}-pair
    # data is the collection of data elements held by this peer
    #
    # Do not block in the event handler of this function!
    #
    defp loop(links, latlon, data, listen_port) do
        this = self
        receive do
            {:newlink, link} ->
              loop([link | links], latlon, data, listen_port)
            
            {:ping, msg_id, from_link, req_options} ->
                spawn_link fn -> Joining.handle_join(this, msg_id, from_link, links, latlon, listen_port, req_options) end
                loop(links, latlon, data, listen_port)
            
            {:pong, msg_id, link} ->
              newlinks = [link | links]
              Logger.info "Current list of links #{inspect newlinks}"
              loop(newlinks, latlon, [], listen_port)

            {:leave, requestor} ->
                spawn fn -> leave(requestor, links) end
            
            {:query, requestor, other_latlon, query, req_options} ->
                spawn_link fn -> Query.handle(requestor, links, latlon, query) end
                loop(links, latlon, data, listen_port)
            {:get_links, requestor} ->
                send(requestor, {:ok, links })
                
            msg ->
                IO.puts "Invalid message #{inspect msg}"
                loop(links, latlon, data, listen_port)
            end
    end

    defp leave(requestor, links) do
        # for each link, tell that you leave
        # close collections
        # return to sender
        send(requestor, {:ok, self()})
    end

end
