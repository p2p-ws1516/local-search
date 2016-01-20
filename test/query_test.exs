defmodule QueryTest do
  use ExUnit.Case
  doctest Query
  import Testutil

  test "Query should match simple values" do
  	peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [])
    Peer.add_item(peer2, "Foo bar")

    Peer.query(peer1, "Foo bar", self)

    assert_receive({:query_hit, "Foo bar", {_,_, {2,2}}})
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )

    :timer.sleep(200)
  end

  test "Query hits should be propagated" do
  	peer1 = peer_join(1, [init: true, maxlinks: 0])
    peer2 = peer_join(2, [bootstrap: 1, maxlinks: 1])
    peer3 = peer_join(3, [bootstrap: 2, maxlinks: 1])
    
    Peer.add_item(peer1, "Foo bar")

    Peer.query(peer3, "Foo bar", self)


    assert_receive({:query_hit, "Foo bar", {_,_, {1,1}}})
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )

    :timer.sleep(200)
  end

  test "Multiple hits should be reported" do
  	peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [bootstrap: 1])
    peer3 = peer_join(3, [bootstrap: 2])
    
    Peer.add_item(peer1, "Foo bar")
    Peer.add_item(peer2, "Foo bar")

    Peer.query(peer3, "Foo bar", self)

    assert_receive({:query_hit, "Foo bar", {_,_, {1,1}}}, 1000)
    assert_receive({:query_hit, "Foo bar", {_,_, {2,2}}}, 1000)
    refute_receive({:query_hit, _, _})

    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )

    :timer.sleep(200)
  end

  test "Query handling should respect TTL" do
  	peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [bootstrap: 1, ttl: 1])
    peer3 = peer_join(3, [bootstrap: 2])
    
    Peer.add_item(peer1, "Foo bar")

    Peer.query(peer3, "Foo bar", self)

    refute_receive({:query_hit, _, _})

    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )

    :timer.sleep(200)
  end

  test "Items should be found in large network" do
  	numpeers = 20
    bootstrap_node = peer_join(-1, [init: true,  maxlinks: numpeers])
    peers = for i <- 0..5, do: peer_join(i, [bootstrap: -1, maxlinks: numpeers]) 
    peers = peers ++ for i <- 6..(numpeers), do: peer_join(i, [bootstrap: i-5, maxlinks: 4, startuptime: 250, sleep: 500]) 

	  {_, lastpeer} = Enum.fetch(peers, numpeers)
    Peer.add_item(lastpeer, "Foo bar")

    new_peer = peer_join(99, [bootstrap: numpeers - 1, maxlinks: 5, ttl: 10, startuptime: 250, sleep: 500])

	  Peer.query(new_peer, "Foo bar", self)

    assert_receive({:query_hit, "Foo bar", {_,_, {numpeers,numpeers}}}, 2000)
    refute_receive({:query_hit, _, _})    

    :ok = Peer.leave( bootstrap_node )
    for p <- peers, do: Peer.leave( p )
    :ok = Peer.leave( new_peer )

    :timer.sleep(5000)
  end

end