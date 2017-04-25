defmodule RNDL.StateServer do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %RNDL.State{}, name: RNDL.StateServer )
  end

  def init(state) do
    {:ok, state}
  end

  def set(key, val) do
    GenServer.call(RNDL.StateServer, {:set, key, val})
  end

  def get_state do
    GenServer.call(RNDL.StateServer, {:get_state})
  end

  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set, key, val}, _from, state) do
    new_state = Map.put(state, key, val)
    {:reply, new_state, new_state}
  end
end
