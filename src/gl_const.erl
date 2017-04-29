-module(gl_const).
-compile(export_all).

-include_lib("wx/include/gl.hrl").

-record(texture, {id, w, h, minx, miny, maxx, maxy}).

gl_smooth() ->
  ?GL_SMOOTH.

gl_depth_test() ->
  ?GL_DEPTH_TEST.

gl_lequal() ->
  ?GL_LEQUAL.

gl_perspective_correction_hint() ->
  ?GL_PERSPECTIVE_CORRECTION_HINT.

gl_nicest() ->
  ?GL_NICEST.

gl_color_buffer_bit() ->
  ?GL_COLOR_BUFFER_BIT.

gl_depth_buffer_bit() ->
  ?GL_DEPTH_BUFFER_BIT.

gl_triangles() ->
  ?GL_TRIANGLES.

gl_quads() ->
  ?GL_QUADS.

gl_line_strip() ->
  ?GL_LINE_STRIP.

gl_projection() ->
  ?GL_PROJECTION.

gl_modelview() ->
  ?GL_MODELVIEW.

gl_texture_2d() ->
  ?GL_TEXTURE_2D.

gl_texture_min_filter() ->
  ?GL_TEXTURE_MIN_FILTER.

gl_texture_mag_filter() ->
  ?GL_TEXTURE_MAG_FILTER.

gl_linear() ->
  ?GL_LINEAR.

load_texture_by_image(Image) ->
  ImageWidth = wxImage:getWidth(Image),
  ImageHeight = wxImage:getHeight(Image),
  Width = get_power_of_two_roof(ImageWidth),
  Height = get_power_of_two_roof(ImageHeight),
  Data = get_image_data(Image),

  % Create opengl texture for the image
  [TextureID] = gl:genTextures(1),
  gl:bindTexture(?GL_TEXTURE_2D, TextureID),
  gl:texParameteri(?GL_TEXTURE_2D, ?GL_TEXTURE_MAG_FILTER, ?GL_LINEAR),
  gl:texParameteri(?GL_TEXTURE_2D, ?GL_TEXTURE_MIN_FILTER, ?GL_LINEAR),
  Format = case wxImage:hasAlpha(Image) of
             true -> ?GL_RGBA;
             false -> ?GL_RGB
           end,
  gl:texImage2D(?GL_TEXTURE_2D, 0, Format, Width, Height, 0, Format, ?GL_UNSIGNED_BYTE, Data),
  #texture{id = TextureID, w = ImageWidth, h = ImageHeight,
    minx = 0, miny = 0, maxx = ImageWidth / Width, maxy = ImageHeight / Height}.

get_image_data(Image) ->
  RGB = wxImage:getData(Image),
  case wxImage:hasAlpha(Image) of
    true ->
      Alpha = wxImage:getAlpha(Image),
      interleave_rgb_and_alpha(RGB, Alpha);
    false ->
      RGB
  end.

interleave_rgb_and_alpha(RGB, Alpha) ->
  list_to_binary(
    lists:zipwith(fun({R, G, B}, A) ->
      <<R, G, B, A>>
                  end,
      [{R,G,B} || <<R, G, B>> <= RGB],
      [A || <<A>> <= Alpha])).


get_power_of_two_roof(X) ->
  get_power_of_two_roof_2(1, X).

get_power_of_two_roof_2(N, X) when N >= X -> N;
get_power_of_two_roof_2(N, X) -> get_power_of_two_roof_2(N*2, X).