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
    
  end
end
