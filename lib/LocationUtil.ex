defmodule LocationUtil do
  
  @doc ~S"""
  Computes the distance between two geographical locations in km

  ##Example
  iex> adlershof = {52.4293128,13.5282168}
  iex> mitte = {52.519801,13.3677223}
  iex> LocationUtil.distance_km(adlershof, adlershof)
  0.0
  iex> LocationUtil.distance_km(adlershof, mitte) 
  14.812315127303867
  iex> LocationUtil.distance_km(mitte, adlershof) 
  14.812315127303867
  """
  def distance_km({lat1, lon1}, {lat2, lon2}) do
    r = 6371; # Radius of the earth in km
    dLat = deg_to_rad(lat2-lat1);
    dLon = deg_to_rad(lon2-lon1); 
    a = 
    :math.sin(dLat/2) * :math.sin(dLat/2) +
    :math.cos(deg_to_rad(lat1)) * :math.cos(deg_to_rad(lat2)) * 
    :math.sin(dLon/2) * :math.sin(dLon/2)
    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1-a)); 
    d = r * c; # distance in km
    d
  end

  defp deg_to_rad(deg) do
    deg * (:math.pi/180)
  end

end