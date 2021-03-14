defmodule CirceTest do
  use ExUnit.Case
  doctest Circe

  test "banana" do

    extractor = Circe.input((
      (Circe.extract(fun).(Circe.extract_splicing(args)) -> Circe.extract(pat)) -> Circe.extract(expr)
    ))

    result = extractor.(quote do (fruit.(3) -> {:ok, :banana}) -> :split end)

    assert result == {:ok, %{
      fun: {:fruit, [], __MODULE__},
      args: [3],
      pat: {:ok, :banana},
      expr: :split,
    }}
  end

  #test "split" do

  #  Circe.output(
  #    case insert(fun).(insert(data), insert_splicing(args)) do
  #      insert(pat) -> insert(expr)
  #      _ -> insert(acc)
  #    end
  #  )
  #end
end
