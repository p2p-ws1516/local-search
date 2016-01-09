defmodule Main do

	def start do
		bootstrap_ip = {192, 168, 0, 1}
		latlon = {10.123123123, 98.123435353}
		Overlay.join(bootstrap_ip, latlon)
	end

end
