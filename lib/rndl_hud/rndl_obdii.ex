defmodule RNDL.OBDII do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: RNDL.OBDII)
  end

  def init(:ok) do
    :timer.send_interval(50, self(), :update)
  end

  def stop do
    GenServer.call(RNDL.OBDII, {:stop})
  end

  def start do
    GenServer.call(RNDL.OBDII, {:start})
  end

  def handle_info(:update, :stopped) do
    {:noreply, :stopped}
  end

  def handle_info(:update, timer) do
    %{rpm: rpm} = RNDL.StateServer.get_state()
    rpm = if rpm >= 7000, do: 0, else: rpm + 50
    RNDL.StateServer.set(:rpm, rpm)
    {:noreply, timer}
  end

  def handle_call({:stop}, _, timer) do
    {:ok, _} = :timer.cancel(timer)
    {:reply, :stopped, :stopped}
  end

  def handle_call({:start}, _, :stopped) do
    {:ok, timer} = init(:ok)
    {:reply, timer, timer}
  end
end
