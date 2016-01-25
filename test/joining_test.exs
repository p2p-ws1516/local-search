defmodule JoiningTest do
  use ExUnit.Case
  doctest Joining
  import Testutil

  test "Joining of one peer" do
    peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [])

    assert Peer.get_links( peer1 ) == set_of([{2, :active}])
    assert Peer.get_links( peer2 ) == set_of([{1, :passive}])
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )

    :timer.sleep(200)
   end

  test "Messages with ttl 0 should be discarded" do
     peer1 = peer_join(1, [init: true])
     peer2 = peer_join(2, [ttl: 0])
    
     assert Peer.get_links( peer1 ) == set_of([])
     assert Peer.get_links( peer2 ) == set_of([])
    
     :ok = Peer.leave( peer1 )
     :ok = Peer.leave( peer2 )

     :timer.sleep(200)
   end

   test "Messages with too large hopcount should be discarded" do
     peer1 = peer_join(1, [init: true])
     peer2 = peer_join(2, [ttl: 1, bootstrap: 1])
     peer3 = peer_join(3, [ttl: 1, bootstrap: 2])
     peer4 = peer_join(4, [ttl: 3, bootstrap: 3])

     assert Peer.get_links( peer1 ) == set_of([{2, :active}])
     assert Peer.get_links( peer2 ) == set_of([{1, :passive},{3, :active}])
     assert Peer.get_links( peer3 ) == set_of([{2, :passive},{4, :active}])
     assert Peer.get_links( peer4 ) == set_of([{3, :passive}])

     :ok = Peer.leave( peer1 )
     :ok = Peer.leave( peer2 )
     :ok = Peer.leave( peer3 )
     :ok = Peer.leave( peer4 )

     :timer.sleep(200)
   end

  test "Messages with ttl > 0 should not be discarded" do
    peer1 = peer_join(1, [init: true, ttl: 1])
    peer2 = peer_join(2, [bootstrap: 1, ttl: 1])
    peer3 = peer_join(3, [bootstrap: 2, ttl: 1])

    assert Peer.get_links( peer1 ) == set_of([{2, :active}])
    assert Peer.get_links( peer2 ) == set_of([{1, :passive}, {3, :active}])
    assert Peer.get_links( peer3 ) == set_of([{2, :passive}])

    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )

    :timer.sleep(200)
  end

  test "Three peers get to know each other" do
    peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [bootstrap: 1])
    peer3 = peer_join(3, [bootstrap: 2])  

    assert Peer.get_links( peer1 ) == set_of([{2, :active}, {3, :active}])
    assert Peer.get_links( peer2 ) == set_of([{1, :passive}, {3, :active}])
    assert Peer.get_links( peer3 ) == set_of([{1, :passive}, {2, :passive}])
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )

    :timer.sleep(200)
  end

  test "New peer should select maxlinks random peers on startup" do
    bootstrap_node = peer_join(0, [init: true])
    peers = for i <- 1..20, do: peer_join(i, [bootstrap: 0, maxlinks: 2]) 

    new_peer = peer_join(99, [bootstrap: 0, maxlinks: 3, ttl: 10])
    assert Set.size(Peer.get_links( new_peer )) == 3

    :ok = Peer.leave( bootstrap_node )
    for p <- peers, do: Peer.leave(p)
    :ok = Peer.leave( new_peer )

    :timer.sleep(200)
  end
  
  test "Peers should handle partial failure on startup" do
    peer1 = peer_join(1, [init: true, maxlinks: 1])
    peer2 = peer_join(2, [bootstrap: 1, maxlinks: 1])
    peer3 = peer_join(3, [bootstrap: 1, maxlinks: 2])  

    assert Peer.get_links( peer1 ) == set_of([{2, :active}, {3, :active}])
    assert Peer.get_links( peer2 ) == set_of([{1, :passive}, {3, :active}])
    assert Peer.get_links( peer3 ) == set_of([{1, :passive}, {2, :passive}])

    :ok = Peer.leave(peer3)

    :timer.sleep(200)

    assert Peer.get_links( peer1 ) == set_of([{2, :active}])
    assert Peer.get_links( peer2 ) == set_of([{1, :passive}])

    peer4 = peer_join(4, [bootstrap: 1])
    assert Peer.get_links( peer1 ) == set_of([{2, :active}, {4, :active}])
    assert Peer.get_links( peer2 ) == set_of([{1, :passive}, {4, :active}])
    assert Peer.get_links( peer4 ) == set_of([{1, :passive}, {2, :passive}])
    
    :ok = Peer.leave(peer1)
    :ok = Peer.leave(peer2)
    :ok = Peer.leave(peer4)

    :timer.sleep(200)
  end

  test "Peers should collect new links if no. links is below maxlinks" do
    peer1 = peer_join(1, [init: true, maxlinks: 3])
    peer2 = peer_join(2, [bootstrap: 1, maxlinks: 3])
    peer3 = peer_join(3, [bootstrap: 1, maxlinks: 3])  
    peer4 = peer_join(4, [bootstrap: 1, maxlinks: 2, startuptime: 100, sleep: 200, refreshtime: 300])

    peer4_links = Peer.get_links( peer4 )
    assert Set.size( peer4_links ) == 2

    {broken_peer_id, others} = cond do 
            Set.member?(peer4_links, get_passive_link(3)) -> {peer3, [peer1, peer2]}
            Set.member?(peer4_links, get_passive_link(2)) -> {peer2, [peer1, peer3]}
            Set.member?(peer4_links, get_passive_link(1)) -> {peer1, [peer2, peer3]}
           end

    Peer.leave(broken_peer_id)

    Peer.add_item(hd(others), "Item")
    # Let peer 4 discover loss of link
    Peer.query(peer4, "Item", self)
    
    # Wait until peer 4 is re-initialized
    :timer.sleep(1000)
    
    peer4_links = Peer.get_links( peer4 )
    assert Set.size( peer4_links ) == 2

    for p <- others, do: Peer.leave(p)
    Peer.leave(peer4)

    :timer.sleep(200)

  end
end
