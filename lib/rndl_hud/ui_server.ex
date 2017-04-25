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
    timer = :timer.send_interval(20, self(), :update)
    {:ok, %{frame: frame, canvas: canvas, timer: timer}}
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
    aspect = width / height
    :glu.ortho2D(0, width, 0, height)
    :ok
  end

  defp draw() do
    state = RNDL.StateServer.get_state()
    percent = (state.rpm / @max_rpm)*460
    :gl.clear(Bitwise.bor(:gl_const.gl_color_buffer_bit, :gl_const.gl_depth_buffer_bit))
    :gl.'begin'(:gl_const.gl_triangles)
    :gl.color3f(1.0, 0.0, 0.0)
    :gl.vertex2f(10, 10)
    :gl.vertex2f(10 + percent, 10)
    :gl.vertex2f(10 + percent, 30)
    :gl.'end'()
    :ok
  end

  defp render(%{canvas: canvas} = _state) do
    draw()
    :wxGLCanvas.swapBuffers(canvas)
    :ok
  end
end
