# Transcoding

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `transcoding` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:transcoding, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/transcoding](https://hexdocs.pm/transcoding).

# Transcoding

A simple module to achieve assets transformation.

Inspired by waffle and jwplayer-thumbnail-preview-generator (for sprites generation)

It persists work in subfolder of the original file, except for sprites, directly in it.

References: 

* [Waffle](https://hexdocs.pm/waffle)
* [JWPlayer thumbnail preview generator](https://github.com/amnuts/jwplayer-thumbnail-preview-generator)
