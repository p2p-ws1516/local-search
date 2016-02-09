defmodule WebLog do
  
  def log( reason, state ) do
    {:ok, socket} = :gen_udp.open(state.listen_port)
    {_status, msg} = JSON.encode(
      [type: reason,
       loc: state.location,
       links: Set.to_list( state.links ) ])
    # remote server
    #:gen_udp.send(socket, {188,226,178,57}, 9876, msg )
    
    # local server
    :gen_udp.send(socket, {127,0,0,1}, 9876, msg )
    :gen_udp.close(socket)
  end
  
end
