defmodule SigilCirceTest do
  use ExUnit.Case

  test "tridot: sigil basic extraction" do
    import Circe

    ast = quote do Module.extract(:split) end
    result = case ast do
      ~m|#{m}.#{f}(#{as})| -> {:ok, %{module: m, function: f, args: as}}
      ~m|#{module}.#{function}(#{... args})| -> {:ok, %{module: module, function: function, args: args}}
    end

    assert result == {:ok, %{
      module: quote(do: Module),
      function: :extract,
      args: :split,
    }}
  end

  test "tridot: sigil basic extraction, spliced args" do
    import Circe

    ast = quote do Module.extract(:split, :split) end
    result = case ast do
      ~m|#{m}.#{f}(#{as})| -> {:ok, %{module: m, function: f, args: as}}
      ~m|#{module}.#{function}(#{...args})| -> {:ok, %{module: module, function: function, args: args}}
    end

    assert result == {:ok, %{
      module: quote(do: Module),
      function: :extract,
      args: [:split, :split],
    }}
  end

  test "tridot: sigil patterned extraction, spliced args" do
    import Circe

    ast = quote do Module.extract(:split, :split) end
    result = case ast do
      ~m|#{{_, _, _} = module}.#{function}(#{...args})| -> {:ok, %{module: module, function: function, args: args}}
    end

    assert result == {:ok, %{
      module: quote(do: Module),
      function: :extract,
      args: [:split, :split],
    }}
  end

  test "tridot: sigil basic extraction, local call, spliced args" do
    import Circe

    ast = quote do extract(:split, :split) end
    result = case ast do
      ~m|#{function}(#{...args})| -> {:ok, %{function: function, args: args}}
    end

    assert result == {:ok, %{
      function: :extract,
      args: [:split, :split],
    }}
  end
end
