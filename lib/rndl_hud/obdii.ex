defmodule RNDL.OBDII do
  use GenServer
  @serial_port "/dev/cu.LGPhone-OBD_Listener"
  @pids ["0C", "0D"]
  @handlers [
    { ~r/41 0C ([0-9A-F]{2} [0-9A-F]{2})/, &RNDL.OBDII.pid_rpm/1 },
    { ~r/41 0D ([0-9A-F]{2})/, &RNDL.OBDII.pid_speed/1 }
  ]

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: RNDL.OBDII)
  end

  def init(:ok) do
    {:ok, serial} = Nerves.UART.start_link()
    Nerves.UART.open(serial, @serial_port, speed: 115200, active: false,
        framing: {Nerves.UART.Framing.Line, separator: "\r"})
    {:ok, _} = send_wait_ok(serial, "ATZ")
    {:ok, _} = send_wait_ok(serial, "ATE0")
    {:ok, _} = send_wait_ok(serial, "ATS1")
    {:ok, _} = send_wait_ok(serial, "ATH0")
    {:ok, _} = send_wait_ok(serial, "ATSP0")

    :ok = Nerves.UART.configure(serial, active: true)
    {:ok, timer} = :timer.send_interval(250, self(), :timer)

    {:ok, {serial, timer}}
  end

  defp send_wait_ok(serial, msg) do
    IO.puts "-> #{msg}"
    :ok = Nerves.UART.write(serial, msg)
    {:ok, res} = Nerves.UART.read(serial, 60000)
    IO.puts ">>> #{res}"
    {:ok, res}
  end

  defp send_logged(serial, msg) do
    IO.puts "-> #{msg}"
    :ok = Nerves.UART.write(serial, msg)
  end

  def handle_info(:timer, {serial, timer}) do
    Enum.each(@pids, fn pid -> send_logged(serial, "01#{pid}") end)
    {:noreply, {serial, timer}}
  end

  def handle_info({:nerves_uart, @serial_port, message}, {serial, timer}) do
    IO.puts ">>> #{message}"
    Enum.each(@handlers, fn {regex, method} ->
      match = Regex.run(regex, message)
      if match do
        [_, capture] = match
        method.(capture)
      end
    end)
    {:noreply, {serial, timer}}
  end

  def pid_speed(raw_speed) do
    speed = String.to_integer(raw_speed, 16)
    RNDL.StateServer.set(:speed, speed)
  end

  def pid_rpm(raw_rpm) do
    [upper, lower] = String.split(raw_rpm, " ")
    rpm = String.to_integer(upper <> lower, 16)
    RNDL.StateServer.set(:rpm, rpm)
  end
end
