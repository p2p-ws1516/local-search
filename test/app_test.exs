defmodule AppTest do
  use ExUnit.Case

  test "the truth" do
    # Start Bootstrap
    peer1 = Peer.join( {{127,0,0,1},9999}, {0,0}, 9999, true )
    :timer.sleep(200)
    
    # Start peer
    peer2 = Peer.join( {{127,0,0,1},9999}, {1,1}, 9998, false )
    :timer.sleep(2000)
    
    # Check links of peer 2
    links2 = Peer.get_links( peer2 )
    assert links2 == ["127.0.0.1:9999@0,0"]
    
    # Check links of peer 1
    links1 = Peer.get_links( peer1 )
    assert links1 == ["127.0.0.1:9998@1,1"]
    
    # IO.puts "lllliiiinnnkkkss   #{inspect links1}"
    #
  end
end
