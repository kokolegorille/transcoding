defmodule TranscodingTest do
  use ExUnit.Case
  doctest Transcoding

  test "greets the world" do
    assert Transcoding.hello() == :world
  end
end
