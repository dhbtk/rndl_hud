defmodule RNDL.UIServer do
  use GenServer
  use Bitwise
  @title "RNDL"
  @size {480, 320}

  @max_rpm 7000
  @rpm_width 300
  @step1 2500
  @step2 4000
  @step3 5750
  @color1 {1, 0.64705884, 0}
  @color2 {1, 0.27058825, 0}
  @color3 {1, 0, 0}

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: RNDL.UIServer)
  end

  def init(:ok) do
    wx = :wx.new([])
    frame = :wxFrame.new(wx, :wx_const.wx_id_any, @title, [{:size, @size}])
    :wxWindow.connect(frame, :close_window)
    :wxFrame.show(frame)
#     :wxFrame.showFullScreen(frame, true)

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
    textures = load_textures()
    timer = :timer.send_interval(50, self(), :update)
    {:ok, %{frame: frame, canvas: canvas, timer: timer, textures: textures}}
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

  def load_textures() do
    Enum.map(0..9, fn i ->
        load_texture_by_file("res/images/7segment/#{i}.png")
     end)
  end

  # as imgs são 90x122 mas arredondamos para 128x128
  def load_texture_by_file(file) do
    img = :wxImage.new(file)
    tex = :gl_const.load_texture_by_image(img)
    IO.inspect tex
    tex
  end

  defp draw(own_state) do
    state = RNDL.StateServer.get_state()
    percent = (state.rpm / @max_rpm)
    :gl.clear(Bitwise.bor(:gl_const.gl_color_buffer_bit, :gl_const.gl_depth_buffer_bit))

    dist = round(percent*@rpm_width)

    :gl.'begin'(:gl_const.gl_quads)
    :gl.color3f(1.0, 1.0, 0.5)
    draw_horizontal_blocks(dist, 0)
    :gl.'end'()

    # white bar
    :gl.'begin'(:gl_const.gl_quads)
    :gl.color3f(1.0, 1.0, 1.0)
    :gl.vertex2f(0, 217)
    :gl.vertex2f(@rpm_width, 217)
    :gl.vertex2f(@rpm_width, 215)
    :gl.vertex2f(0, 215)
    :gl.'end'()

    tach_label_step = @rpm_width/(@max_rpm/1000)

    Enum.each(0..round(@max_rpm/1000), fn i ->
        x = tach_label_step*i
        x = unless i == 0, do: x - 6, else: x
        draw_digit(i, x, 210, 12, own_state)
    end)
    state.speed
        |> round
        |> Integer.to_string
        |> String.pad_leading(3, "0")
        |> draw_number(310, 290, 56, own_state)

    state.rpm
        |> round
        |> Integer.to_string
        |> String.pad_leading(4, "0")
        |> draw_number(0, 190, 20, own_state)

    :gl.'begin'(:gl_const.gl_triangles)
    :gl.color3f(1.0, 1.0, 0.5)
    :gl.vertex2f(100, 10)
    :gl.vertex2f(100 + percent*360, 10)
    :gl.vertex2f(100 + percent*360, 30)
    :gl.'end'()
    :ok
  end

  defp draw_horizontal_blocks(x, x) do
    :ok
  end

  defp draw_horizontal_blocks(max_x, min_x) do
    width = max_x - min_x
    colored_width = if width > 10, do: 10, else: width

    {r, g, b} = color_for_block(@rpm_width, min_x)
    :gl.color3f(r, g, b)
    :gl.vertex2f(min_x, 220)
    :gl.vertex2f(min_x + colored_width, 220)
    :gl.vertex2f(min_x + colored_width, 320)
    :gl.vertex2f(min_x, 320)

    next_min = min(max_x, min_x + colored_width + 2)
    draw_horizontal_blocks(max_x, next_min)
  end

  defp color_for_block(max_x, min_x) do
    rpm = (min_x/max_x) * @max_rpm
    color_for_rpm(rpm)
  end

  defp color_for_rpm(rpm) when rpm > @step3 do
    @color3
  end

  defp color_for_rpm(rpm) when rpm > @step2 do
    mult = (rpm - @step2) / (@step3 - @step2)
    interpolate_color(@color2, @color3, mult)
  end

  defp color_for_rpm(rpm) when rpm > @step1 do
    mult = (rpm - @step1) / (@step2 - @step1)
    interpolate_color(@color1, @color2, mult)
  end

  defp color_for_rpm(rpm) do
    @color1
  end

  defp interpolate_color(c1, _c2, _p) when _p <= 0 do
    c1
  end

  defp interpolate_color(_c1, c2, _p) when _p >= 1 do
    c2
  end

  defp interpolate_color(c1, c2, p) do
    {r1, g1, b1} = c1
    {r2, g2, b2} = c2
    {r1 + (r2 - r1) * p, g1 + (g2 - g1) * p, b1 + (b2 - b1) * p}
  end

  defp draw_number(<<>>, x, y, w, state) do
    :ok
  end

  defp draw_number(n, x, y, w, state) do
    rest = n |> String.slice(1..-1)
    digit = n |> String.at(0) |> String.to_integer
    draw_digit(digit, x, y, w, state)
    draw_number(rest, x + w, y, w, state)
  end

  defp draw_digit(n, x, y, w, %{textures: textures} = _state) do
    tex = Enum.at(textures, n)
    h = (w/90)*122
    :gl.enable(:gl_const.gl_texture_2d)
    :gl.texParameterf(:gl_const.gl_texture_2d, :gl_const.gl_texture_min_filter, :gl_const.gl_linear)
    :gl.texParameterf(:gl_const.gl_texture_2d, :gl_const.gl_texture_mag_filter, :gl_const.gl_linear)
    :gl.bindTexture(:gl_const.gl_texture_2d(), elem(tex, 1))
    :gl.'begin'(:gl_const.gl_quads)

    maxx = 90/128
    maxy = 122/128

    # tl -> tr -> br -> bl
    :gl.texCoord2f(0, 0)
    :gl.vertex2f(x, y)
    :gl.texCoord2f(maxx, 0)
    :gl.vertex2f(x + w, y)
    :gl.texCoord2f(maxx, maxy)
    :gl.vertex2f(x + w, y - h)
    :gl.texCoord2f(0, maxy)
    :gl.vertex2f(x, y - h)
    :gl.'end'()
    :gl.disable(:gl_const.gl_texture_2d)
  end

  defp render(%{canvas: canvas} = state) do
    draw(state)
    :wxGLCanvas.swapBuffers(canvas)
    :ok
  end
end
