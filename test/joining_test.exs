defmodule JoiningTest do
  use ExUnit.Case
  doctest Joining
  import Testutil

  test "001 Joining of one peer" do
    peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [])
    
    assert_links peer1, [{2, :active}]
    assert_links peer2, [{1, :passive}]


    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )

    :timer.sleep(200)
   end

  test "002 Messages with ttl 0 should be discarded" do
     peer1 = peer_join(1, [init: true])
     peer2 = peer_join(2, [ttl: 0])
    
     assert_links peer1, []
     assert_links peer2, []
    
     :ok = Peer.leave( peer1 )
     :ok = Peer.leave( peer2 )

     :timer.sleep(200)
   end

   test "003 Messages with too large hopcount should be discarded" do
     peer1 = peer_join(1, [init: true])
     peer2 = peer_join(2, [ttl: 1, bootstrap: 1])
     peer3 = peer_join(3, [ttl: 1, bootstrap: 2])
     peer4 = peer_join(4, [ttl: 3, bootstrap: 3])

     assert_links peer1, [{2, :active}]
     assert_links peer2, [{1, :passive},{3, :active}]
     assert_links peer3, [{2, :passive},{4, :active}]
     assert_links peer4, [{3, :passive}]

     :ok = Peer.leave( peer1 )
     :ok = Peer.leave( peer2 )
     :ok = Peer.leave( peer3 )
     :ok = Peer.leave( peer4 )

     :timer.sleep(200)
   end

  test "004 Messages with ttl > 0 should not be discarded" do
    peer1 = peer_join(1, [init: true, ttl: 1])
    peer2 = peer_join(2, [bootstrap: 1, ttl: 1])
    peer3 = peer_join(3, [bootstrap: 2, ttl: 1])

    assert_links peer1, [{2, :active}]
    assert_links peer2, [{1, :passive},{3, :active}]
    assert_links peer3, [{2, :passive}]

    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )

    :timer.sleep(200)
  end

  test "005 Three peers get to know each other" do
    peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [bootstrap: 1])
    peer3 = peer_join(3, [bootstrap: 2])  

    assert_links peer1, [{2, :active}, { 3, :active}]
    assert_links peer2, [{1, :passive},{ 3, :active}]
    assert_links peer3, [{1, :passive}, {2, :passive}]
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )

    :timer.sleep(200)
  end

  test "006 New peer should select maxlinks random peers on startup" do
    bootstrap_node = peer_join(0, [init: true])
    peers = for i <- 1..20, do: peer_join(i, [bootstrap: 0, maxlinks: 2]) 

    new_peer = peer_join(99, [bootstrap: 0, maxlinks: 3, ttl: 10])
    assert length(Peer.get_links( new_peer )) == 3

    :ok = Peer.leave( bootstrap_node )
    for p <- peers, do: Peer.leave(p)
    :ok = Peer.leave( new_peer )

    :timer.sleep(200)
  end
  
  test "007 Peers should handle partial failure on startup" do
    peer1 = peer_join(1, [init: true, maxlinks: 1])
    peer2 = peer_join(2, [bootstrap: 1, maxlinks: 1])
    peer3 = peer_join(3, [bootstrap: 1, maxlinks: 2])  

    assert_links peer1, [{2, :active }, {3, :active}]
    assert_links peer2, [{1, :passive}, {3, :active}]
    assert_links peer3, [{1, :passive}, {2, :passive}]

    :ok = Peer.leave(peer3)

    :timer.sleep(200)

    assert_links peer1, [{2, :active}]
    assert_links peer2, [{1, :passive}]

    peer4 = peer_join(4, [bootstrap: 1])
    assert_links peer1, [{2, :active}, {4, :active}]
    assert_links peer2, [{1, :passive},{4, :active}]
    assert_links peer4, [{1, :passive},{2, :passive}]
    
    :ok = Peer.leave(peer1)
    :ok = Peer.leave(peer2)
    :ok = Peer.leave(peer4)

    :timer.sleep(200)
  end

  test "008 Peers should collect new links if no. links is below maxlinks" do
    peer1 = peer_join(1, [init: true, maxlinks: 3])
    peer2 = peer_join(2, [bootstrap: 1, maxlinks: 3])
    peer3 = peer_join(3, [bootstrap: 1, maxlinks: 3])  
    peer4 = peer_join(4, [bootstrap: 1, maxlinks: 2, startuptime: 100, sleep: 200, refreshtime: 300])

    peer4_links = Peer.get_links( peer4 )
    assert length( peer4_links ) == 2

    {broken_peer_id, others} = cond do 
            Enum.member?(peer4_links, get_passive_link(3)) -> {peer3, [peer1, peer2]}
            Enum.member?(peer4_links, get_passive_link(2)) -> {peer2, [peer1, peer3]}
            Enum.member?(peer4_links, get_passive_link(1)) -> {peer1, [peer2, peer3]}
           end

    Peer.leave(broken_peer_id)

    Peer.add_item(hd(others), "Item")
    # Let peer 4 discover loss of link
    Peer.query(peer4, "Item", [], self)
    
    # Wait until peer 4 is re-initialized
    :timer.sleep(1200)
    
    peer4_links = Peer.get_links( peer4 )
    assert length( peer4_links ) == 2

    for p <- others, do: Peer.leave(p)
    Peer.leave(peer4)

    :timer.sleep(200)

  end

  test "009 Peers should not discover duplicate links" do
    peer1 = peer_join(1, [init: true, maxlinks: 2, refreshtime: 50, sleep: 50, startuptime: 50])
    peer2 = peer_join(2, [bootstrap: 1, maxlinks: 2])

    :timer.sleep(500)

    assert length(Peer.get_links(peer1)) == 1

    Peer.leave(peer1)
    Peer.leave(peer2)
  end

end
