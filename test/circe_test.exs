defmodule CirceTest do
  use ExUnit.Case
  doctest Circe

  test "greets the world" do
    assert Circe.hello() == :world
  end
end
