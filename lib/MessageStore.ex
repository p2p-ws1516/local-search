defmodule MessageStore do

  def empty() do
  	{:ok, pid} = Agent.start_link(fn -> %{} end)
    pid
  end

  def put_own_message(_, nil, _) do
  end

  def put_own_message(state, msg_id, value) do
    store = state.mymessages
    Agent.update(store, &Map.put(&1, msg_id, value))    
  end

  def put_other_message(_, nil, _) do
  end

  def put_other_message(state, msg_id, value) do
      store = state.othermessages
      Agent.update(store, &Map.put(&1, msg_id, value))  
  end

  def get_other_message(state, msg_id) do
    store = state.othermessages
    Agent.get(store, &Map.get(&1, msg_id))
  end

  def get_own_message(state, msg_id) do
    store = state.mymessages
    Agent.get(store, &Map.get(&1, msg_id))
  end

  def is_known_message(state, msg_id) do
    my_store = state.mymessages
    other_store = state.othermessages
    Agent.get(my_store, &Map.has_key?(&1, msg_id)) or Agent.get(other_store, &Map.has_key?(&1, msg_id))
  end

  def is_own_message(state, msg_id) do
    store = state.mymessages
    Agent.get(store, &Map.has_key?(&1, msg_id))
  end

  def is_other_message(state, msg_id) do
    store = state.othermessages
    Agent.get(store, &Map.has_key?(&1, msg_id))
  end

end