defmodule Testutil do

  def listen_port_base, do: 9000
  def send_port_base, do: 8000

  def ip, do: {127, 0, 0, 1}

  #
  # initializes a default peer used for this test
  #
  def peer_join(id, opts) do
    ttl = Keyword.get(opts, :ttl, 7)
    maxlinks = Keyword.get(opts, :maxlinks, 2)
    bootstrap_port = 9000 + Keyword.get(opts, :bootstrap, 1)
    init = Keyword.get(opts, :init, false)
    startuptime = Keyword.get(opts, :startuptime, 200)
    refreshtime = Keyword.get(opts, :refreshtime, 60000)  # we usually do not want this in tests
    lat = Keyword.get(opts, :lat, id)
    lon = Keyword.get(opts, :lon, id)
    sleep = Keyword.get(opts, :sleep, 400)
    config = [ttl: ttl, maxlinks: maxlinks, startuptime: startuptime, refreshtime: refreshtime, sleep: sleep]
    { :ok, peer } = if (init) do
        Peer.join(%{ location: {lat,lon}, send_port: (send_port_base + id), listen_port: (listen_port_base + id), config: config, bootstrap: [] })        
    else
        Peer.join(%{ location: {lat,lon}, send_port: (send_port_base + id), listen_port: (listen_port_base + id), bootstrap: [ {{127,0,0,1}, bootstrap_port} ], config: config })
    end
    :timer.sleep(sleep)
    peer
  end

  #
  # gets the default link for a peer with given id in this test 
  #
  def get_peer_link(id) do
      {{127, 0, 0, 1}, (send_port_base + id), {id, id}}
  end

  #
  # gets the default link for a peer with given id in this test
  # the port is the one seen by the other peer! 
  #
  def get_passive_link(id) do
      {{127, 0, 0, 1}, (listen_port_base + id), {id, id}}
  end

  defmacro assert_links(peer, []) do 
    quote do
      links = Peer.get_links( unquote(peer) )
      assert links == []
    end
  end

  defmacro assert_links(peer, ids) do 
    quote do
    links = Peer.get_links( unquote(peer) )
    for {link, {id, status}} <- Enum.zip(links, unquote(ids)) do
      case status do
        :active ->
          {address, port, {lat, lon}} = link
           assert {address, port, {lat, lon}} == {ip, port, {id, id}}
        :passive ->
          {address, port, {lat, lon}} = link
           assert {address, port, {lat, lon}} == {ip, (listen_port_base + id), {id, id}}
      end
    end
  end
end
end
