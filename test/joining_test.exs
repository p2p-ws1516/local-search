defmodule JoiningTest do
  use ExUnit.Case
  doctest Joining

  test "Joining of one peer" do
    peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [])

    assert Peer.get_links( peer1 ) == set_of([2])
    assert Peer.get_links( peer2 ) == set_of([1])
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
  end

  test "Messages with ttl 0 should be discarded" do
    peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [ttl: 0])
    
    assert Peer.get_links( peer1 ) == set_of([])
    assert Peer.get_links( peer2 ) == set_of([])
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
  end

  test "Messages with too large hopcount should be discarded" do
    peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [ttl: 1, bootstrap: 1])
    peer3 = peer_join(3, [ttl: 1, bootstrap: 2])
    peer4 = peer_join(4, [ttl: 3, bootstrap: 3])

    assert Peer.get_links( peer1 ) == set_of([2])
    assert Peer.get_links( peer2 ) == set_of([1,3])
    assert Peer.get_links( peer3 ) == set_of([2,4])
    assert Peer.get_links( peer4 ) == set_of([3])

    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )
    :ok = Peer.leave( peer4 )
  end

  test "Messages with ttl > 0 should not be discarded" do
    peer1 = peer_join(1, [init: true, ttl: 1])
    peer2 = peer_join(2, [bootstrap: 1, ttl: 1])
    peer3 = peer_join(3, [bootstrap: 2, ttl: 1])

    assert Peer.get_links( peer1 ) == set_of([2])
    assert Peer.get_links( peer2 ) == set_of([1, 3])
    assert Peer.get_links( peer3 ) == set_of([2])

    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )
  end

  test "Peer should not accept more than maxlinks" do
    maxlinks = 2
    peer1 = peer_join(1, [init: true, maxlinks: maxlinks])
    peer2 = peer_join(2, [maxlinks: maxlinks])
    peer3 = peer_join(3, [maxlinks: maxlinks])
    peer4 = peer_join(4, [maxlinks: 3])

    assert Peer.get_links( peer1 ) == set_of([2, 3])
    assert Peer.get_links( peer2 ) == set_of([1, 3])
    assert Peer.get_links( peer3 ) == set_of([1, 2])
    assert Peer.get_links( peer4 ) == set_of([1, 2, 3])
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )
    :ok = Peer.leave( peer4 )

  end

  test "Three peers get to know each other" do
    peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [bootstrap: 1])
    peer3 = peer_join(3, [bootstrap: 2])  

    assert Peer.get_links( peer1 ) == set_of([2, 3])
    assert Peer.get_links( peer2 ) == set_of([1, 3])
    assert Peer.get_links( peer3 ) == set_of([1, 2])
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )
  end

  test "New peer should select maxlinks random peers on startup" do
    bootstrap_node = peer_join(0, [init: true])
    peers = for i <- 1..10, do: peer_join(i, [bootstrap: 0, maxlinks: 10]) 

    new_peer = peer_join(99, [bootstrap: 0, maxlinks: 3, ttl: 10])
    assert Set.size(Peer.get_links( new_peer )) == 3

    :ok = Peer.leave( bootstrap_node )
    for p <- peers, do: Peer.leave(p)
    :ok = Peer.leave( new_peer )

  end

  test "Peers should handle partial failure on startup" do
    peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [bootstrap: 1])
    peer3 = peer_join(3, [bootstrap: 1])  

    :ok = Peer.leave(peer3)

    # not yet realized that 3 is gone
    assert Peer.get_links( peer1 ) == set_of([2, 3])
    assert Peer.get_links( peer2 ) == set_of([1, 3])

    peer4 = peer_join(4, [bootstrap: 1])
    assert Peer.get_links( peer1 ) == set_of([2, 4])
    assert Peer.get_links( peer2 ) == set_of([1, 4])
    assert Peer.get_links( peer4 ) == set_of([1, 2])
    
    :ok = Peer.leave(peer1)
    :ok = Peer.leave(peer2)
    :ok = Peer.leave(peer4)

  end

  #
  # initializes a default peer used for this test
  #
  defp peer_join(id, opts) do
    ttl = Keyword.get(opts, :ttl, 7)
    maxlinks = Keyword.get(opts, :maxlinks, 5)
    bootstrap_port = 9000 + Keyword.get(opts, :bootstrap, 1)
    init = Keyword.get(opts, :init, false)
    startuptime = Keyword.get(opts, :startuptime, 25)
    config = [ttl: ttl, maxlinks: maxlinks, startuptime: startuptime]
    { :ok, peer } = if (init) do
        Peer.join(%{ location: {id,id}, listen_port: (9000 + id), config: config })        
    else
        Peer.join(%{ location: {id,id}, listen_port: (9000 + id), bootstrap: [ {{127,0,0,1}, bootstrap_port} ], config: config })
    end
    :timer.sleep(50)
    peer
  end

  #
  # gets the default link for a peer with given id in this test 
  #
  defp get_peer_link(id) do
      {{127, 0, 0, 1}, (9000 + id), {id, id}}
  end

  defp set_of(ids) do
    Enum.map(ids, &get_peer_link/1) |> Enum.into(HashSet.new)
  end 

end
