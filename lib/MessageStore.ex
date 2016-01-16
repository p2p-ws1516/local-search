defmodule MessageStore do

  def empty() do
  	{:ok, pid} = Agent.start_link(fn -> %{} end)
    pid
  end

  def put_own_message(state, nil) do
  end

  def put_own_message(state, msg_id) do
    store = state.mymessages
    Agent.update(store, &Map.put(&1, msg_id, nil))    
  end

  def put_other_message(state, nil, value) do
  end

  def put_other_message(state, msg_id, value) do
      store = state.othermessages
      Agent.update(store, &Map.put(&1, msg_id, value))  
  end

  def get_other_message(state, msg_id) do
    store = state.othermessages
    Agent.get(store, &Map.get(&1, msg_id))
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