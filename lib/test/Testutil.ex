defmodule Testutil do

  #
  # initializes a default peer used for this test
  #
  def peer_join(id, opts) do
    ttl = Keyword.get(opts, :ttl, 7)
    maxlinks = Keyword.get(opts, :maxlinks, 5)
    bootstrap_port = 9000 + Keyword.get(opts, :bootstrap, 1)
    init = Keyword.get(opts, :init, false)
    startuptime = Keyword.get(opts, :startuptime, 50)
    sleep = Keyword.get(opts, :sleep, 100)
    config = [ttl: ttl, maxlinks: maxlinks, startuptime: startuptime, sleep: sleep]
    { :ok, peer } = if (init) do
        Peer.join(%{ location: {id,id}, listen_port: (9000 + id), config: config })        
    else
        Peer.join(%{ location: {id,id}, listen_port: (9000 + id), bootstrap: [ {{127,0,0,1}, bootstrap_port} ], config: config })
    end
    :timer.sleep(sleep)
    peer
  end

  #
  # gets the default link for a peer with given id in this test 
  #
  def get_peer_link(id) do
      {{127, 0, 0, 1}, (9000 + id), {id, id}}
  end

  def set_of(ids) do
    Enum.map(ids, &get_peer_link/1) |> Enum.into(HashSet.new)
  end 
	
end