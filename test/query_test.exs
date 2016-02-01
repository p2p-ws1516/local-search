defmodule QueryTest do
  use ExUnit.Case
  doctest Query
  import Testutil

  test "Query should match simple values" do
    peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [])
    Peer.add_item(peer2, "Foo bar")

    Peer.query(peer1, "Foo bar", [], self)

    assert_receive({:query_hit, ["Foo bar"], {_,_, {2,2}}})
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )

    :timer.sleep(200)
  end

  test "Query should match partial values" do
    peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [])
    Peer.add_item(peer2, "Foo bar")
    Peer.add_item(peer2, "XYFooZ")

    Peer.query(peer1, "Foo", [], self)

    assert_receive({:query_hit, ["XYFooZ", "Foo bar"], {_,_, {2,2}}})
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )

    :timer.sleep(200)
  end

  test "Query should match regex" do
    peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [])
    Peer.add_item(peer2, "Bike 123")
    Peer.add_item(peer2, "Car 456")
    Peer.add_item(peer2, "Book")

    Peer.query(peer1, "B.*\d*", [], self)

    assert_receive({:query_hit, ["Book", "Bike 123"], {_,_, {2,2}}})
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )

    :timer.sleep(200)
  end


  test "queries traverse bidirectional links" do
    peer1 = peer_join(1, [init: true])
    peer2 = peer_join(2, [bootstrap: 1])
    
    Peer.add_item(peer2, "Foo bar")
    Peer.query(peer1, "Foo bar", [], self)

    assert_receive({:query_hit, ["Foo bar"], {_,_, {2,2}}})

    :ok = Peer.leave(peer1)
    :ok = Peer.leave(peer2)

    :timer.sleep(200)
  end

  test "Query hits should be propagated" do
    peer1 = peer_join(1, [init: true, maxlinks: 0])
    peer2 = peer_join(2, [bootstrap: 1, maxlinks: 1])
    peer3 = peer_join(3, [bootstrap: 2, maxlinks: 1])
    
    Peer.add_item(peer1, "Foo bar")

    Peer.query(peer3, "Foo bar", [], self)

    assert_receive({:query_hit, ["Foo bar"], {_,_, {1,1}}})
    
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

    Peer.query(peer3, "Foo bar", [], self)

    assert_receive({:query_hit, ["Foo bar"], {_,_, {1,1}}}, 1000)
    assert_receive({:query_hit, ["Foo bar"], {_,_, {2,2}}}, 1000)
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

    Peer.query(peer3, ["Foo bar"], [], self)

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
    peers = peers ++ for i <- 6..(numpeers), do: peer_join(i, [bootstrap: i-5, maxlinks: 4 ]) 

    {_, lastpeer} = Enum.fetch(peers, numpeers)
    Peer.add_item(lastpeer, "Foo bar")

    new_peer = peer_join(99, [bootstrap: numpeers - 1, maxlinks: 5, ttl: 10 ])

    Peer.query(new_peer, "Foo bar", [], self)

    assert_receive({:query_hit, ["Foo bar"], {_,_, {numpeers,numpeers}}}, 500)
    refute_receive({:query_hit, _, _})    

    :ok = Peer.leave( bootstrap_node )
    for p <- peers, do: Peer.leave( p )
    :ok = Peer.leave( new_peer )

    :timer.sleep(200)
  end

  test "Search is location aware" do
    peer_adlershof = peer_join(1, [init: true, lat: 52.4293128, lon: 13.5282168])
    peer_mitte = peer_join(2, [bootstrap: 1, lat: 52.519801, lon: 13.3677223])
    peer_neukoelln = peer_join(3, [bootstrap: 2, lat: 52.468927, lon: 13.4397813])
    
    Peer.add_item(peer_mitte, "Item 1")
    Peer.add_item(peer_neukoelln, "Item 2")
    
    Peer.query(peer_adlershof, "Item", [radius: 10], self)

    # We have a match in Neukoelln
    assert_receive({:query_hit, ["Item 2"], {{127,0,0,1}, 9003, {52.468927,13.4397813}}}, 500)
    # But not in Mitte (> 10 km from Adlershof)
    refute_receive({:query_hit, _, _})

    :ok = Peer.leave( peer_adlershof )
    :ok = Peer.leave( peer_mitte )
    :ok = Peer.leave( peer_neukoelln )

    :timer.sleep(200)
  end

end