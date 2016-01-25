defmodule Testutil do

  def listen_port_base, do: 9000
  def send_port_base, do: 8000

  #
  # initializes a default peer used for this test
  #
  def peer_join(id, opts) do
    ttl = Keyword.get(opts, :ttl, 7)
    maxlinks = Keyword.get(opts, :maxlinks, 2)
    bootstrap_port = 9000 + Keyword.get(opts, :bootstrap, 1)
    init = Keyword.get(opts, :init, false)
    startuptime = Keyword.get(opts, :startuptime, 100)
    refreshtime = Keyword.get(opts, :refreshtime, 60000)  # we usually do not want this in tests
    sleep = Keyword.get(opts, :sleep, 200)
    config = [ttl: ttl, maxlinks: maxlinks, startuptime: startuptime, refreshtime: refreshtime, sleep: sleep]
    { :ok, peer } = if (init) do
        Peer.join(%{ location: {id,id}, send_port: (send_port_base + id), listen_port: (listen_port_base + id), config: config })        
    else
        Peer.join(%{ location: {id,id}, send_port: (send_port_base + id), listen_port: (listen_port_base + id), bootstrap: [ {{127,0,0,1}, bootstrap_port} ], config: config })
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

  def set_of(ids) do
    Enum.map(ids, 
      fn {id, :active} ->
        get_peer_link(id)
      {id, :passive} ->
        get_passive_link(id)
      end
    ) |> Enum.into(HashSet.new)
  end 
	
end