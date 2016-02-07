defmodule WebLog do
  
  def log(state) do
    IO.puts inspect state
    {:ok, socket} = :gen_udp.open(9877)
    {_status, msg} = JSON.encode(
      [type: "test",
       loc: state.location,
       links: state.links ])
    :gen_udp.send(socket, {127,0,0,1}, 9876, msg )
    :gen_udp.close(socket)
  end
  
end
