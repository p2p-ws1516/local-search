defmodule WebLog do
  
  def log( reason, state ) do
    {log_ip, log_port} = state.log
    unless log_ip == nil or log_port == nil do
      {:ok, socket} = :gen_udp.open(state.listen_port)
      {_status, msg} = JSON.encode(
      [type: reason,
       loc: state.location,
       links: Set.to_list( state.links ) ])
      :gen_udp.send(socket, log_ip, log_port, msg )
      :gen_udp.close(socket)      
    end
  end
  
end
