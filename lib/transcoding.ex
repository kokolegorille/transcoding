defmodule Transcoding do
  @moduledoc """
  Documentation for `Transcoding`.
  """

  require Logger

  # id: id of the resource
  # type: eg. :medium, :thumbnail
  # version: eg, :thumb
  # path: path to file
  # cmd to apply

  # content_type=image/jpeg
  # filename=s_1C4D1591CADC57205E88CF17E0B735562AA29A2...
  # hash=a91f028a5752d7e0bf316e38c24b98273d96d8cb1...
  # id=a5bb35c5-c145-47db-9db2-dacf25f6abd2
  # path=/home/sqrt/DATA_2021/app4am_uploads/thumb...
  # size=84842
  # type=thumbnail

  def test_thumbnail do
    ## THUMBNAIL TRANSFORM

    transformations = [
      {:mini, {:convert, "-resize 160x90^ -gravity center -extent 160x90 -format png"}, :png},
      {:thumb, {:convert, "-resize 256x144^ -gravity center -extent 256x144 -format png"}, :png},
      {:large, {:convert, "-resize 640x360^ -gravity center -extent 640x360 -format png"}, :png}
    ]

    file = "/home/sqrt/DATA_2021/app4am_uploads/thumbnail/a5bb35c5-c145-47db-9db2-dacf25f6abd2/s_1C4D1591CADC57205E88CF17E0B735562AA29A2AA6A546E3AA530EF47972F419_1605717370998_032.jpg"

    # TODO: Chech file exists

    # extension = :png

    dir = Path.dirname(file)
    filename = Path.basename(file, Path.extname(file))

    Enum.map(transformations, fn {key, transform, extension} ->
      Logger.info "Processing #{key}"

      new_filename = "#{filename}.#{extension}"

      key = to_string(key)
      new_dir = Path.join([dir, key])

      unless File.exists?(new_dir), do: File.mkdir!(new_dir)

      dest = Path.join([new_dir, new_filename])

      case process(file, dest, transform) do
        :ok ->
          {:ok, %{
            # "id" => id,
            "filename" => new_filename,
            # "type" => type,
            "path" => dest,
            # "hash" => do_hash_file(dest)
          }}
        {:error, error} -> {:error, error}
      end
    end)
  end

  def test_medium do
    file = "/home/sqrt/DATA_2021/app4am_uploads/medium/a5bb35c5-c145-47db-9db2-dacf25f6abd2/Kluski Śląskie @ Jalapeño Bilingüe.mp4"

    # file = "/home/sqrt/DATA_2021/app4am_uploads/medium/a5bb35c5-c145-47db-9db2-dacf25f6abd2/alice-a-pestalozzi.mp4"

    # Animated gif
    # Poster
    # Sprite
    # Scale resolution

    # # To take a thumbnail from a video:
    # {:ffmpeg, fn(input, output) -> "-i #{input} -f jpg #{output}" end, :jpg}
    # # To convert a video to an animated gif
    # {:ffmpeg, fn(input, output) -> "-i #{input} -f gif #{output}" end, :gif}

    ## SPRITE FOR JWPLAYER
    # https://jwplayer-support-archive.netlify.app/questions/6062703-can-thumbnail-sprites-be-created-with-ffmpeg-#
    #
    # This is what you want:

    # ffmpeg -i somemovie.mp4 -vf 'thumbnail=TAKE_ONE_OF_EVERY_X_FRAMES,scale=80:45,tile=5x8:nb_frames=40:padding=0:margin=0' -an -vsync 0 overview.jpg


    # TAKE_ONE_OF_EVERY_X_FRAMES is the tricky number, that you will have to calculate based on the framerate and length of your inputfile.
    # If the number is not right, you end with more then one sprite image.

    # to get framerate
    # $ ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate Kluski\ Śląskie\ @\ Jalapeño\ Bilingüe.mp4
    # 30/1



    # If the name of the file has white space, it will break...
    # => Provide a list of arguments instead

    # A pipeline can have multiple extensions! eg :gif, :jpg, :png

    # It will hang if the file exists! => add -y

    transformations = [
      ## NOT WORKING!
      # {:animated_gif, {:ffmpeg, fn input, output -> "-y -i \"#{input}\" -f #{extension} \"#{output}\"" end}},
      # {:animated_gif, {:ffmpeg, fn input, output -> "-y -i #{input} -f #{extension} #{output}" end}},

      # {:animated_gif, {:ffmpeg, fn input, output -> ["-y", "-i",  input,  "-t", "5.0", "-ss", "10.0", "-f",  to_string(:gif), output] end}, :gif},

      # {:animated_gif, {:ffmpeg, fn input, output -> ["-y", "-i",  input, "-vf", "scale=320:-1", "-t", "5.0", "-ss", "10.0", output] end}, :gif},

      # {:animated_gif, {:ffmpeg, fn input, output -> ["-y", "-i",  input, "-vf", "scale=320:-1", "-t", "5.0", "-ss", "7.0", output] end}, :gif},

      # {:poster, {:ffmpeg, fn input, output -> ["-y", "-i",  input,  "-vf", "scale=320:-1", "-ss", "10.0", "-frames:v", "1", output] end}, :png},

      {:animated_gif, {:ffmpeg, fn input, output -> ["-y", "-i",  input, "-vf", "scale=256:144", "-t", "5.0", "-ss", "10.0", output] end}, :gif},

      {:poster_thumb, {:ffmpeg, fn input, output -> ["-y", "-i",  input,  "-vf", "scale=256:144", "-ss", "10.0", "-frames:v", "1", "-f", "image2", output] end}, :png},

      {:poster_large, {:ffmpeg, fn input, output -> ["-y", "-i",  input,  "-vf", "scale=640:360", "-ss", "10.0", "-frames:v", "-f", "image2", "1", output] end}, :png},

      # {:sprite, {:ffmpeg, fn input, output -> ["-y", "-i", input, "-vf", "thumbnail=90,scale=80:45,tile=5x8:nb_frames=40:padding=0:margin=0", "-an", "-vsync", "0", output] end}, :jpg},
      # {:sprite, {:ffmpeg, fn input, output -> ["-y", "-i", input, "-vf", "thumbnail=90,scale=80:-1,tile=10x5:nb_frames=40:padding=0:margin=0", "-an", "-vsync", "0", output] end}, :jpg},

      # 7680 x 4320
      # 3840 × 2160
      # 1980 x 1080
      # 1280 x 720
      # 1024 x 576
      # 768 x 432
      # 512 x 288
      # 256 x 144

      # It's possible to use libx264 too
      # crf is for quality control (0: lossless, default: 23, 51: worst)
      # It's possible to add -preset veryslow

      # {:resize_1080, {:ffmpeg, fn input, output -> ["-y", "-i", input, "-vf", "scale=-1:1080", "-vcodec", "libx265", "-crf", "0", output] end}, :mp4},
      # {:resize_720, {:ffmpeg, fn input, output -> ["-y", "-i", input, "-vf", "scale=-1:720", "-vcodec", "libx265", "-crf", "0", output] end}, :mp4},
      # {:resize_576, {:ffmpeg, fn input, output -> ["-y", "-i", input, "-vf", "scale=-1:576", "-vcodec", "libx265", "-crf", "0", output] end}, :mp4},
      # {:resize_432, {:ffmpeg, fn input, output -> ["-y", "-i", input, "-vf", "scale=-1:432", "-vcodec", "libx265", "-crf", "0", output] end}, :mp4},
      # {:resize_288, {:ffmpeg, fn input, output -> ["-y", "-i", input, "-vf", "scale=-1:288", "-vcodec", "libx265", "-crf", "0", output] end}, :mp4},
      # {:resize_144, {:ffmpeg, fn input, output -> ["-y", "-i", input, "-vf", "scale=-1:144", "-vcodec", "libx265", "-crf", "0", output] end}, :mp4},
    ]

    dir = Path.dirname(file)
    filename = Path.basename(file, Path.extname(file))

    # Logger.info(dir)

    Enum.map(transformations, fn {key, transform, extension} ->
      Logger.info "Processing #{key} #{inspect transform}"

      new_filename = "#{filename}.#{extension}"

      key = to_string(key)
      new_dir = Path.join([dir, key])

      Logger.info "NEW DIR : #{new_dir}"

      unless File.exists?(new_dir), do: File.mkdir!(new_dir)

      dest = Path.join([new_dir, new_filename])

      Logger.info("DEST : #{dest}")

      case process(file, dest, transform) do
        :ok ->
          {:ok, %{
            # "id" => id,
            "filename" => new_filename,
            # "type" => type,
            "path" => dest,
            # "hash" => do_hash_file(dest)
          }}
        {:error, error} -> {:error, error}
      end
    end)
  end

  def jw_player_thumbnails do
    # file = "/home/sqrt/DATA_2021/app4am_uploads/medium/a5bb35c5-c145-47db-9db2-dacf25f6abd2/alice-a-pestalozzi.mp4"
    file = "/home/sqrt/DATA_2021/app4am_uploads/medium/a5bb35c5-c145-47db-9db2-dacf25f6abd2/Kluski Śląskie @ Jalapeño Bilingüe.mp4"
    # file = "/home/sqrt/DATA_2021/app4am_uploads/medium/a5bb35c5-c145-47db-9db2-dacf25f6abd2/kflay.mp4"

    file_dir = Path.dirname(file)

    tmp_key = 10
    |> :crypto.strong_rand_bytes()
    |> :base64.encode()

    dest = Path.join([file_dir, "_tmp_#{tmp_key}"])

    unless File.exists?(dest), do: File.mkdir!(dest)

    # This will return an exit code of 1, because no output file is specified

    {:error, details} = process(file, dest, {:ffmpeg, fn input, _output -> ["-i",  input] end})

    #########################################
    ## DURATION
    #########################################

    map = Regex.named_captures(~r/Duration: ((?<hours>\d+):(?<minutes>\d+):(?<seconds>\d+))\.\d+, start: (?<start>[^,]*)/is, details)

    duration = String.to_integer(map["hours"]) * 3_600 +
      String.to_integer(map["minutes"]) * 60 +
      String.to_integer(map["seconds"])

    Logger.info("DURATION => #{duration}")

    start = map["start"]
    |> String.to_float()
    |> Kernel.+(0.0001)
    |> :erlang.float_to_binary([decimals: 4])

    Logger.info("START => #{start}")

    # %{
    #   "duration" => "00:02:25",
    #   "hours" => "00",
    #   "minutes" => "02",
    #   "seconds" => "25",
    #   "start" => "0.000000"
    # }

    #########################################
    ## TBR
    #########################################

    map = Regex.named_captures(~r/\b(?<tbr>\d+(?:\.\d+)?) tbr\b/, details)

    tbr = String.to_integer(map["tbr"])

    Logger.info("TBR => #{tbr}")

    # %{"tbr" => "30"}

    name = Path.basename(file, Path.extname(file))
    timespan = 10
    thumb_width = 120
    sprite_width = 10

    # ffmpeg -ss %0.04f -i %s -y -an -sn -vsync 0 -q:v 5 -threads 1 -vf scale=%d:-1,select="not(mod(n\,%d))" "%s/thumbnails/%s-%%04d.jpg" 2>&1

    # shell_exec(sprintf($commands['thumbs'],
    #   $start + .0001, $params['input'], $params['thumbWidth'],
    #   $params['timespan'] * $tbr, $params['output'], $name
    # ));

    # [
    #   "-y", "-i", file, "-ss", "#{start}", "-an", "-sn", "-vsync", "0", "-q:v", "5", "-threads", "1",
    #   "-vf", "scale=#{thumb_width}:-1,select=\"not(mod(n, #{timespan * tbr}))\"", "#{dest}/#{name}-%%04d.jpg"
    # ]

    # ffmpeg -y -i alice-a-pestalozzi.mp4 -an -sn -vsync 0 -q:v 5 -threads 1 -vf "scale=120:-1,select='not(mod(n,300))'" thumbnails/f-%04d.jpg

    fun = fn input, _output ->
      [
        "-y", "-i", input, "-ss", "#{start}", "-an", "-sn", "-vsync", "0", "-q:v", "5", "-threads", "1",
        "-vf", "scale=#{thumb_width}:-1,select=not(mod(n\\, #{timespan * tbr}))", "#{dest}/#{name}-%04d.jpg"
      ]
    end

    process file, dest, {:ffmpeg, fun}

    # READ DIR
    # files = Path.wildcard(Path.join(dest, "*.jpg"))
    [first_sprite | _] = files = dest
    |> Path.join("*.jpg")
    |> Path.wildcard()
    |> Enum.sort()

    Logger.info("FILES: #{inspect files}")

    # COUNT
    total = Enum.count(files)
    Logger.info("TOTAL: #{total}")

    # GET IMAGE INFO
    {_, w, h, _} = first_sprite
    |> File.read!()
    |> ExImageInfo.info()

    Logger.info("Width/Height: #{w} #{h}")

    thumb_across = min(total, sprite_width)
    rows = Float.ceil(total / thumb_across)
    width = w * thumb_across
    height = h * rows

    Logger.info("WIDTH/HEIGHT: #{width} #{height}")

    # GENERATE SPRITE
    # Use montage to build sprite

    # montage_dest = Path.dirname(file)

    sprite_name = "sprite.jpg"
    sprite_image = Path.join([file_dir, sprite_name])

    # montage_args = ["#{dest}/*.jpg", "-tile", "#{thumb_across}x#{rows}", "-geometry", "#{w}x#{h}+0+0", Path.join([montage_dest, sprite_name])]
    montage_args = ["#{dest}/*.jpg", "-tile", "#{thumb_across}x#{rows}", "-geometry", "#{w}x#{h}+0+0", sprite_image]

    case System.cmd("montage", montage_args, stderr_to_stdout: true) do
      {_, 0} ->
        :ok
      {error_message, exit_code} ->
        Logger.info "EXIT CODE : #{exit_code}"

        {:error, error_message}
    end

    # GENERATE VTT

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

    # ITERATE OVER RANGE

    initial_acc = %{rx: 0, ry: 0, s: 0, vtt: "WEBVTT\n\n"}

    %{vtt: vtt} = Enum.reduce(0..(total - 1), initial_acc, fn f, acc ->
      t1 = time_to_string(acc.s)
      s = acc.s + timespan
      t2 = time_to_string(s)

      {rx, ry} = if f > 0 && rem(f, thumb_across) == 0,
        do: {0, acc.ry + 1 },
        else: {(acc.rx), acc.ry}

      vtt = acc.vtt <> "#{t1} ---> #{t2}\n#{sprite_name}#xywh=#{rx * w},#{ry * h},#{w},#{h}" <> "\n\n"

      %{acc | s: s, rx: rx + 1, vtt: vtt}
    end)

    Logger.info("VTT: #{vtt}")

    # File.write!(Path.join([montage_dest, "sprite.vtt"]), vtt)
    sprite_vtt = Path.join([file_dir, "sprite.vtt"])
    File.write!(sprite_vtt, vtt)

    # CLEAN UP

    File.rm_rf!(dest)

    {:ok, %{sprite_image: sprite_image, sprite_vtt: sprite_vtt}}
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
    time
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  # def process(file, dest, {cmd, conversion}) do
  #   apply(cmd, file, dest, conversion)
  # end

  # def apply(cmd, file, dest, args) do
  #   # This allow to pass a function
  #   # ffmpeg requires something like "-i #{input} #{output}"
  #   args = if is_function(args),
  #     do: args.(file, dest),
  #     else: [file | String.split(args, " ") ++ [dest]]

  #   program = to_string(cmd)

  #   ensure_executable_exists!(program)

  #   args = args_list(args)

  #   Logger.info "ARGS : #{inspect(args)}"

  #   case System.cmd(program, args, stderr_to_stdout: true) do
  #     {_, 0} ->
  #       :ok
  #     {error_message, exit_code} ->
  #       Logger.info "EXIT CODE : #{exit_code}"

  #       {:error, error_message}
  #   end
  # end

  def process(file, dest, {cmd, conversion}) do
    # This allow to pass a function
    # ffmpeg requires something like "-i #{input} #{output}"
    conversion = if is_function(conversion),
      do: conversion.(file, dest),
      else: [file | String.split(conversion, " ") ++ [dest]]

    exec(to_string(cmd), conversion)
  end

  def exec(program, args) do
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
