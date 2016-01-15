defmodule JoiningTest do
  use ExUnit.Case

  test "Joining of one peer" do
    # Start Bootstrap
    { :ok, peer1 } = Peer.join(%{ location: {0,0}, listen_port: 9999 })
    :timer.sleep(200)
    
    # Start peer
    { :ok, peer2 } = Peer.join(%{
      location: {1,1},
      listen_port: 9998,
      bootstrap: [ {{127,0,0,1},9999} ]
    })
    :timer.sleep(200)
    
    # Check links of peer 2
    links2 = Peer.get_links( peer2 )
    assert links2 == [{{127, 0, 0, 1}, 9999, {0, 0}}]
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )

  end

  test "Three peers get to know each other" do
    # Start Bootstrap
    { :ok, peer1 } = Peer.join(%{ location: {0,0}, listen_port: 9999 })
    :timer.sleep(200)
    
    # Start peer 2
    { :ok, peer2 } = Peer.join(%{
      location: {1,1},
      listen_port: 9998,
      bootstrap: [ {{127,0,0,1},9999} ]
    })
    :timer.sleep(200)

     # Start peer 3 using peer 2
    { :ok, peer3 } = Peer.join(%{
      location: {2,2},
      listen_port: 9997,
      bootstrap: [ {{127,0,0,1},9998} ]
    })
    :timer.sleep(200)
    
    # Check links of peer 2
    links2 = Peer.get_links( peer2 )
    assert links2 == [{{127, 0, 0, 1}, 9999, {0, 0}}]

    # Check links of peer 2
    links3 = Peer.get_links( peer3 )
    assert links3 == [{{127, 0, 0, 1}, 9999, {0, 0}}, {{127, 0, 0, 1}, 9998, {1, 1}}]
    
    :ok = Peer.leave( peer1 )
    :ok = Peer.leave( peer2 )
    :ok = Peer.leave( peer3 )
  end

end
