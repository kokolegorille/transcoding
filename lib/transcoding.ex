defmodule Transcoding do
  @moduledoc """
  Documentation for `Transcoding`.

  Transcode image or movie to potentially multiple output

  image -> thumbnails
  movie -> thumbnails
  movie -> animated_gif
  movie -> sprites (for jwplayer_thumbnail_preview, sprite.jpg & sprite.vtt)

  ## References:
  * https://github.com/amnuts/jwplayer-thumbnail-preview-generator
  * https://jwplayer-support-archive.netlify.app/questions/6062703-can-thumbnail-sprites-be-created-with-ffmpeg-#

  """

  require Logger

  # API

  @doc"""
  Transform an image to multiples thumbnails.

  ## Examples

      f = "test/fixtures/file_example_PNG_3MB.png"
      ts = [mini: [resize: "160x90^"], thumb: [resize: "256x144^"], large: [resize: "640x360^"]]
      Transcoding.transform_image_to_thumbnails f, ts

  """
  def transform_image_to_thumbnails(file, params) do
    transformations = Enum.map(params, fn {k, v} ->
      build_transform(:image_to_thumbnail, k, v)
    end)
    handle_transform(file, transformations)
  end

  @doc"""
  Transform an image to a thumbnail.

  ## Options
    * `:resize` - set the default size, default to "256x144^"
    * `:format` - set the thumbnail format, default to :png
  """
  def transform_image_to_thumbnail(file, key, opts \\ []),
    do: handle_transform(file, build_transform(:image_to_thumbnail, key, opts))

  @doc"""
  Transform a movie to multiples thumbnails.

  ## Examples

      f = "test/fixtures/file_example_MP4_1920_18MG.mp4"
      ts = [mini: [scale: "160x90"], thumb: [scale: "256x144"], large: [scale: "640x360"]]
      Transcoding.transform_movie_to_thumbnails f, ts

  """
  def transform_movie_to_thumbnails(file, params) do
    transformations = Enum.map(params, fn {k, v} ->
      build_transform(:movie_to_thumbnail, k, v)
    end)
    handle_transform(file, transformations)
  end

  @doc"""
  Transform a movie to a thumbnail.

  ## Options
    * `:format` - set the thumbnail format, default to :png
    * `:ss` - set the seek position
    * `:scale`- scale of image
  """
  def transform_movie_to_thumbnail(file, key, opts \\ []),
    do: handle_transform(file, build_transform(:movie_to_thumbnail, key, opts))

  @doc"""
  Transform a movie to an animated gif.

  This should be a unique tranformation.

  ## Options
    * `:t` - set the gif duration
    * `:ss` - set the seek position
    * `:scale`- scale of image

  ## Examples

      f = "test/fixtures/file_example_MP4_1920_18MG.mp4"
      Transcoding.transform_movie_to_animated_gif f, :animated_gif, [scale: "256:144"]

  """
  def transform_movie_to_animated_gif(file, key, opts \\ []),
    do: handle_transform(file, build_transform(:movie_to_animated_gif, key, opts))

  @doc"""
  Transform a movie to multiple resizes.

  This can take very long time...

  ## Resolutions

  7680 x 4320 => 4K
  3840 × 2160 => 2K
  1980 x 1080 => FullHD
  1280 x 720
  1024 x 576
  768 x 432
  512 x 288
  256 x 144

  ## Examples

      f = "test/fixtures/file_example_MP4_1920_18MG.mp4"
      ts = [
        resize_1080: [scale: "-1:1080"],
        resize_720: [scale: "-1:720"],
        resize_576: [scale: "-1:576"],
        resize_432: [scale: "-1:432"],
        resize_288: [scale: "-1:288"],
        resize_144: [scale: "-1:144"],
      ]
      Transcoding.transform_movie_to_resizes f, ts

  """
  def transform_movie_to_resizes(file, params) do
    transformations = Enum.map(params, fn {k, v} ->
      build_transform(:resize_movie, k, v)
    end)
    handle_transform(file, transformations)
  end

  @doc"""
  Transform a movie to a resize.

  ## Options
    * `:vcodec` - set codec to use, eg: "libx264", "libx265" (default)
    * `:crf` - set the quality, 0 lossless, 51: worst
    * `:scale`- scale of image

  """
  def transform_movie_to_resize(file, key, opts \\ []),
    do: handle_transform(file, build_transform(:resize_movie, key, opts))

  @doc"""
  Transform a movie to a sprites.

  Custom transformation

  ## Options
    * `:timespan` - time between each screenshots in seconds
    * `:thumb_width` - max width of the thumbnail
    * `:sprite_width`- number of thumbnails per row

  ## Examples

      f = "test/fixtures/file_example_MP4_1920_18MG.mp4"
      Transcoding.transform_movie_to_sprites f

  """
  def transform_movie_to_sprites(file, opts \\ []) do
    timespan = Keyword.get(opts, :timespan, 10)
    thumb_width = Keyword.get(opts, :thumb_width, 120)
    sprite_width = Keyword.get(opts, :sprite_width, 10)

    # This will be the output dir of the sprite files
    file_dir = Path.dirname(file)

    name = Path.basename(file, Path.extname(file))

    # Generate a random tmp directory
    # which will be deleted after work
    dest = Path.join([file_dir, "_tmp_#{:rand.uniform(1_000_000)}"])

    unless File.exists?(dest), do: File.mkdir!(dest)

    %{duration: _duration, start: start, tbr: tbr} = extract_file_info(file)

    # Generate thumbnails, use a func that returns a list
    fun = fn input, _output ->
      [
        "-y", "-i", input, "-ss", "#{start}", "-an", "-sn", "-vsync", "0", "-q:v", "5", "-threads", "1",
        "-vf", "scale=#{thumb_width}:-1,select=not(mod(n\\, #{timespan * tbr}))", "#{dest}/#{name}-%04d.jpg"
      ]
    end

    process file, dest, {:ffmpeg, fun}

    # Read tmp_dir and list thumbnails
    [first_sprite | _] = files = dest
    |> Path.join("*.jpg")
    |> Path.wildcard()
    |> Enum.sort()

    total = Enum.count(files)

    # Get Image Info from ExImageInfo
    #
    # w: width of a single thumbnail
    # h: height of a single thumbnail

    {_, w, h, _} = first_sprite |> File.read!() |> ExImageInfo.info()

    thumb_across = min(total, sprite_width)
    rows = Float.ceil(total / thumb_across)
    # width = w * thumb_across
    # height = h * rows

    # Generate Sprite Image with montage instead of php-gd
    sprite_image_name = "sprite.jpg"
    sprite_image = Path.join([file_dir, sprite_image_name])

    montage_args = ["#{dest}/*.jpg", "-tile", "#{thumb_across}x#{rows}", "-geometry", "#{w}x#{h}+0+0", sprite_image]

    # Expect the command to always succeed
    :ok = exec("montage", montage_args)

    # Generate VTT
    #
    # Original Php code
    #
    # $vtt = "WEBVTT\n\n";
    # for ($rx = $ry = $s = $f = 0; $f < $total; $f++) {
    #     $t1 = sprintf('%02d:%02d:%02d.000', ($s / 3600), ($s / 60 % 60), $s % 60);
    #     $s += $params['timespan'];
    #     $t2 = sprintf('%02d:%02d:%02d.000', ($s / 3600), ($s / 60 % 60), $s % 60);
    #     if (isset($opts['v'])) {
    #         $vtt .= "{$t1} --> {$t2}\nthumbnails/" . basename($files[$f]);
    #     } else {
    #         if ($f && !($f % $thumbsAcross)) {
    #             $rx = 0;
    #             ++$ry;
    #         }
    #         imagecopymerge($coalesce, imagecreatefromjpeg($files[$f]), $rx * $sizes[0], $ry * $sizes[1], 0, 0, $sizes[0], $sizes[1], 100);
    #         $vtt .= sprintf("%s --> %s\nthumbnails.jpg#xywh=%d,%d,%d,%d", $t1, $t2, $rx++ * $sizes[0], $ry * $sizes[1],  $sizes[0], $sizes[1]);
    #     }
    #     $vtt .= "\n\n";
    # }

    initial_acc = %{rx: 0, ry: 0, s: 0, vtt: "WEBVTT\n\n"}

    %{vtt: vtt} = Enum.reduce(0..(total - 1), initial_acc, fn f, acc ->
      t1 = time_to_string(acc.s)
      s = acc.s + timespan
      t2 = time_to_string(s)

      {rx, ry} = if f > 0 && rem(f, thumb_across) == 0,
        do: {0, acc.ry + 1 },
        else: {(acc.rx), acc.ry}

      vtt = acc.vtt <> "#{t1} ---> #{t2}\n#{sprite_image_name}#xywh=#{rx * w},#{ry * h},#{w},#{h}" <> "\n\n"

      %{acc | s: s, rx: rx + 1, vtt: vtt}
    end)

    sprite_vtt_name = "sprite.vtt"
    sprite_vtt = Path.join([file_dir, sprite_vtt_name])
    File.write!(sprite_vtt, vtt)

    # Clean Up tmp directory
    File.rm_rf!(dest)

    {:ok,
      %{
        sprite_image: new_file(sprite_image_name, sprite_image),
        sprite_vtt: new_file(sprite_vtt_name, sprite_vtt),
      }
    }
  end

  # Private

  # Helpers to build transformation from type, key and options
  defp build_transform(:image_to_thumbnail, key, opts) do
    resize = Keyword.get(opts, :resize, "256x144^")
    format = Keyword.get(opts, :format, :png)
    {key, {:convert, "-resize #{resize} -gravity center -extent #{resize} -format #{format}"}, format}
  end

  defp build_transform(:movie_to_thumbnail, key, opts) do
    scale = Keyword.get(opts, :scale, "256x144")
    ss = Keyword.get(opts, :ss, 10.0)
    format = Keyword.get(opts, :format, :png)
    {key, {:ffmpeg,
      fn input, output ->
        ["-y", "-i",  input,  "-vf", "scale=#{scale}", "-ss", "#{ss}", "-frames:v", "1", "-f", "image2", output]
      end}, format}
  end

  defp build_transform(:movie_to_animated_gif, key, opts) do
    t = Keyword.get(opts, :t, 5.0)
    ss = Keyword.get(opts, :ss, 10.0)
    scale = Keyword.get(opts, :scale, "256:144")
    {key, {:ffmpeg, fn input, output ->
      ["-y", "-i",  input, "-vf", "scale=#{scale}", "-t", "#{t}", "-ss", "#{ss}", output]
      end}, :gif}
  end

  # It's possible to add -preset veryslow
  defp build_transform(:resize_movie, key, opts) do
    vcodec = Keyword.get(opts, :vcodec, "libx265")
    crf = Keyword.get(opts, :crf, 10)
    scale = Keyword.get(opts, :scale, "-1:720")
    {key, {:ffmpeg,
      fn input, output ->
        ["-y", "-i", input, "-vf", "scale=#{scale}", "-vcodec", "#{vcodec}", "-crf", "#{crf}", output]
      end}, :mp4}
  end

  # Processor

  # defp handle_transform(file, transformations) when is_list(transformations) do
  #   tasks = for t <- transformations do
  #     Task.async(fn -> handle_transform(file, t) end)
  #   end

  #   tasks_with_results = Task.yield_many(tasks, 6_000_000)

  #   Enum.map(tasks_with_results, fn {task, res} ->
  #     # Shut down the tasks that did not reply nor exit
  #     res || Task.shutdown(task, :brutal_kill)
  #   end)
  # end

  defp handle_transform(file, transformations) when is_list(transformations) do
    tasks = for t <- transformations do
      Task.async(fn -> handle_transform(file, t) end)
    end

    tasks_with_results = Task.yield_many(tasks, :infinity)

    Enum.map(tasks_with_results, fn {_task, res} ->
      res
    end)
  end

  # Sample Php code
  #
  # shell_exec(sprintf($commands['thumbs'],
  #   $start + .0001, $params['input'], $params['thumbWidth'],
  #   $params['timespan'] * $tbr, $params['output'], $name
  # ));
  defp handle_transform(file, {key, transform, extension}) do
    Logger.info "Processing #{key} w/ #{extension} #{inspect transform}"

    dir = Path.dirname(file)
    filename = Path.basename(file, Path.extname(file))
    new_filename = "#{filename}.#{extension}"
    key = to_string(key)
    new_dir = Path.join([dir, key])

    unless File.exists?(new_dir), do: File.mkdir!(new_dir)

    dest = Path.join([new_dir, new_filename])

    case process(file, dest, transform) do
      :ok -> {:ok, new_file(new_filename, dest)}
      {:error, error} -> {:error, error}
    end
  end

  defp new_file(name, dest) do
    extension = name |> Path.extname() |> String.trim_leading(".")
    %{
      "filename" => name,
      "path" => dest,
      "content_type" => MIME.type(extension)
    }
  end

  defp extract_file_info(file) do
    # This will return an exit code of 1, because no output file is specified.
    # This is an expected error :-)
    # and the return will contains file information

    {:error, details} = exec("ffmpeg", ["-i",  file])

    # DURATION & START
    regex = ~r/Duration: ((?<hours>\d+):(?<minutes>\d+):(?<seconds>\d+))\.\d+, start: (?<start>[^,]*)/is
    map = Regex.named_captures(regex, details)

    duration = String.to_integer(map["hours"]) * 3_600 +
      String.to_integer(map["minutes"]) * 60 +
      String.to_integer(map["seconds"])

    start = map["start"]
      |> String.to_float()
      |> Kernel.+(0.0001)
      |> :erlang.float_to_binary([decimals: 4])

    # TBR
    regex = ~r/\b(?<tbr>\d+(?:\.\d+)?) tbr\b/
    map = Regex.named_captures(regex, details)

    tbr = String.to_integer(map["tbr"])

    %{duration: duration, start: start, tbr: tbr}
  end

  defp time_to_string(nil), do: nil
  defp time_to_string(time) when is_integer(time) do
    seconds = time |> rem(60) |> pad_time()
    total_in_minutes = div(time, 60)
    minutes = total_in_minutes |> rem(60) |> pad_time()
    hours = total_in_minutes |> div(60) |> pad_time()
    "#{hours}:#{minutes}:#{seconds}.000"
  end

  defp pad_time(time) do
    time |> Integer.to_string() |> String.pad_leading(2, "0")
  end

  defp process(file, dest, {cmd, conversion}) do
    # This allow to pass a function
    # ffmpeg requires something like "-i #{input} #{output}"
    conversion = if is_function(conversion),
      do: conversion.(file, dest),
      else: [file | String.split(conversion, " ") ++ [dest]]

    exec(to_string(cmd), conversion)
  end

  defp exec(program, args) do
    ensure_executable_exists!(program)
    args = args_list(args)
    # Logger.info "ARGS : #{inspect(args)}"

    case System.cmd(program, args, stderr_to_stdout: true) do
      {_, 0} ->
        :ok
      {error_message, _exit_code} ->
        {:error, error_message}
    end
  end

  defp args_list(args) when is_list(args), do: args
  # THIS WILL NOT SPLIT CORRECTLY IF SPACE IN NAME!
  # Prefer list of args instead
  defp args_list(args), do: ~w(#{args})

  defp ensure_executable_exists!(program) when is_binary(program) do
    unless System.find_executable(program),
      do: raise "Executable #{program} not found"
  end
end
