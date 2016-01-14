defmodule AppTest do
  use ExUnit.Case

  test "the truth" do
    # Start Bootstrap
    { :ok, peer1 } = Peer.join(%{ location: {0,0}, listen_port: 9999 })
    :timer.sleep(200)
    
    # Start peer
    { :ok, peer2 } = Peer.join(%{
      location: {1,1},
      listen_port: 9998,
      links: [ {{127,0,0,1},9999} ]
    })
    :timer.sleep(2000)
    
    IO.puts "#{inspect peer2} #{inspect peer1}"
    
    send peer2, "omg"
    
    # Check links of peer 2
    links2 = Peer.get_links( peer2 )
    assert links2 == [{{127, 0, 0, 1}, 9999}]
    
    # Check links of peer 1
    # links1 = Peer.get_links( peer1 )
    # assert links1 == ["127.0.0.1:9998@1,1"]
    
    # IO.puts "lllliiiinnnkkkss   #{inspect links1}"
    #
  end
end
