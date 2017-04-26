defmodule RNDL.UIServer do
  use GenServer
  use Bitwise
  @title "RNDL"
  @size {480, 320}

  @max_rpm 7000

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: RNDL.UIServer)
  end

  def init(:ok) do
    wx = :wx.new([])
    frame = :wxFrame.new(wx, :wx_const.wx_id_any, @title, [{:size, @size}])
    :wxWindow.connect(frame, :close_window)
    :wxFrame.show(frame)
    # :wxFrame.showFullScreen(frame, true)

    opts = [{:size, @size}]
    gl_attrib = [{:attribList, [:wx_const.wx_gl_rgba,
                                :wx_const.wx_gl_doublebuffer,
                                :wx_const.wx_gl_min_red, 8,
                                :wx_const.wx_gl_min_green, 8,
                                :wx_const.wx_gl_min_blue, 8,
                                :wx_const.wx_gl_depth_size, 24, 0]}]
    canvas = :wxGLCanvas.new(frame, opts ++ gl_attrib)

    :wxGLCanvas.connect(canvas, :size)
    :wxWindow.reparent(canvas, frame)
    :wxGLCanvas.setCurrent(canvas)
    setup_gl(canvas)

    # Periodically send a message to trigger a redraw of the scene
    timer = :timer.send_interval(50, self(), :update)
    {:ok, %{frame: frame, canvas: canvas, timer: timer}}
  end

  def terminate(_reason, state) do
    :wxGLCanvas.destroy(state.canvas)
    :timer.cancel(state.timer)
    :timer.sleep(300)
  end

  # genserver

  def handle_info(:update, state) do
    :wx.batch(fn -> render(state) end)
    {:noreply, state}
  end

  # private

  defp setup_gl(win) do
    {w, h} = :wxWindow.getClientSize(win)
    resize_gl_scene(w, h)
    :gl.clearColor(0.0, 0.0, 0.0, 0.0)
    :ok
  end

  defp resize_gl_scene(width, height) do
    :gl.viewport(0, 0, width, height)
    :gl.matrixMode(:gl_const.gl_projection)
    :gl.loadIdentity()
    :glu.ortho2D(0, width, 0, height)
    :ok
  end

  defp draw() do
    state = RNDL.StateServer.get_state()
    percent = (state.rpm / @max_rpm)
    :gl.clear(Bitwise.bor(:gl_const.gl_color_buffer_bit, :gl_const.gl_depth_buffer_bit))

    max_bars = round((@max_rpm/1000) * 7)
    max_angle = 120
    min_angle = 60
    angle_span = min_angle / max_bars
    x_radius = 460
    y_radius = 115
    x_inner_radius = x_radius * 0.9
    y_inner_radius = y_radius * 0.9
    x_center = 240
    y_center = 170

    # wrapper line
    :gl.'begin'(:gl_const.gl_line_strip)
    :gl.color3f(1.0, 1.0, 1.0)
    Enum.each((0..max_bars), fn i ->
      left_rad = ((max_angle - angle_span * i)*:math.pi())/180
      x = :math.cos(left_rad) * x_inner_radius + x_center
      y = y_center + :math.sin(left_rad) * y_inner_radius
      :gl.vertex2f(x, y)
    end)
    :gl.'end'()

    bars = round(percent * max_bars) - 1
    Enum.each(0..bars, fn i ->
      left_rad = ((max_angle - angle_span * i)*:math.pi())/180
      right_rad = ((max_angle - angle_span * (i + 1))*:math.pi())/180
      # bottom: inner_radius
      # top: radius
      x_bl = :math.cos(left_rad) * x_inner_radius + x_center
      y_bl = :math.sin(left_rad) * y_inner_radius + y_center
      x_tl = :math.cos(left_rad) * x_radius + x_center
      y_tl = :math.sin(left_rad) * y_radius + y_center
      x_tr = :math.cos(right_rad) * x_radius + x_center
      y_tr = :math.sin(right_rad) * y_radius + y_center
      x_br = :math.cos(right_rad) * x_inner_radius + x_center
      y_br = :math.sin(right_rad) * y_inner_radius + y_center

      :gl.'begin'(:gl_const.gl_quads)
      if rem(i, 2) != 0 do
        :gl.color3f(1, 0.3, 0)
      else
        :gl.color3f(0, 0, 0)
      end
      :gl.vertex2f(x_bl, y_bl)
      :gl.vertex2f(x_tl, y_tl)
      :gl.vertex2f(x_tr, y_tr)
      :gl.vertex2f(x_br, y_br)
      :gl.'end'()
    end)

    :gl.'begin'(:gl_const.gl_triangles)
    :gl.color3f(1.0, 1.0, 0.5)
    :gl.vertex2f(10, 10)
    :gl.vertex2f(10 + percent*460, 10)
    :gl.vertex2f(10 + percent*460, 30)
    :gl.'end'()
    :ok
  end

  defp render(%{canvas: canvas} = _state) do
    draw()
    :wxGLCanvas.swapBuffers(canvas)
    :ok
  end
end
