defmodule JoiningTest do
  use ExUnit.Case

  test "Joining of one peer" do
    config = [ttl: 7, maxlinks: 5]
    # Start Bootstrap
    { :ok, peer1 } = Peer.join(%{ location: {0,0}, listen_port: 9999, config: config })
    :timer.sleep(200)
    
    # Start peer
    { :ok, peer2 } = Peer.join(%{ location: {1,1}, listen_port: 9998, bootstrap: [ {{127,0,0,1},9999} ], config: config })
    :timer.sleep(200)
    
    assert Peer.get_links( peer1 ) == Enum.into([{{127, 0, 0, 1}, 9998, {1, 1}}], HashSet.new)
    assert Peer.get_links( peer2 ) == Enum.into([{{127, 0, 0, 1}, 9999, {0, 0}}], HashSet.new)
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )

  end

  test "Peer does not accept more than maxlinks" do
    config = [ttl: 7, maxlinks: 2]
    # Start Bootstrap
    { :ok, peer1 } = Peer.join(%{ location: {0,0}, listen_port: 9999, config: config })
    :timer.sleep(200)
    
    # Start peer
    { :ok, peer2 } = Peer.join(%{ location: {1,1}, listen_port: 9998, bootstrap: [ {{127,0,0,1}, 9999} ], config: config })
    :timer.sleep(200)

    # Start peer
    { :ok, peer3 } = Peer.join(%{ location: {2,2}, listen_port: 9997, bootstrap: [ {{127,0,0,1}, 9999} ], config: config })
    :timer.sleep(200)

    # Start peer
    { :ok, peer4 } = Peer.join(%{ location: {3,3}, listen_port: 9996, bootstrap: [ {{127,0,0,1}, 9999} ], config: config })
    :timer.sleep(1000)

    assert Peer.get_links( peer1 ) == Enum.into([{{127, 0, 0, 1}, 9998, {1, 1}}, {{127, 0, 0, 1}, 9997, {2, 2}}], HashSet.new)
    assert Peer.get_links( peer2 ) == Enum.into([{{127, 0, 0, 1}, 9999, {0, 0}}, {{127, 0, 0, 1}, 9997, {2, 2}}], HashSet.new)
    assert Peer.get_links( peer3 ) == Enum.into([{{127, 0, 0, 1}, 9999, {0, 0}}, {{127, 0, 0, 1}, 9998, {1, 1}}], HashSet.new)
    assert Peer.get_links( peer4 ) == Enum.into([{{127, 0, 0, 1}, 9999, {0, 0}}, {{127, 0, 0, 1}, 9998, {1, 1}}], HashSet.new)

    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )
    :ok = Peer.leave( peer4 )

  end

  test "Three peers get to know each other" do
    config = [ttl: 7, maxlinks: 5]
    # Start Bootstrap
    { :ok, peer1 } = Peer.join(%{ location: {0,0}, listen_port: 9999, config: config })
    :timer.sleep(200)
    
    # Start peer 2
    { :ok, peer2 } = Peer.join(%{location: {1,1}, listen_port: 9998, bootstrap: [ {{127,0,0,1},9999} ], config: config })
    :timer.sleep(200)

     # Start peer 3 using peer 2
    { :ok, peer3 } = Peer.join(%{ location: {2,2}, listen_port: 9997, bootstrap: [ {{127,0,0,1},9998} ], config: config })
    :timer.sleep(200)

    assert Peer.get_links( peer1 ) == Enum.into([{{127, 0, 0, 1}, 9997, {2, 2}}, {{127, 0, 0, 1}, 9998, {1, 1}}], HashSet.new)
    assert Peer.get_links( peer2 ) == Enum.into([{{127, 0, 0, 1}, 9997, {2, 2}}, {{127, 0, 0, 1}, 9999, {0, 0}}], HashSet.new)
    assert Peer.get_links( peer3 ) == Enum.into([{{127, 0, 0, 1}, 9998, {1, 1}}, {{127, 0, 0, 1}, 9999, {0, 0}}], HashSet.new)
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )
  end

  test "Three peers get to know each other via peer in the middle" do
  end

end
