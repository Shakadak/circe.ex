defmodule CirceTest do
  use ExUnit.Case
  doctest Circe

  test "banana case" do
    require Circe

    ast = quote do (fruit.(3) -> {:ok, :banana}) -> :split end
    result = case ast do
      Circe.match((
        (Circe.extract(fun).(Circe.extract_splicing(args)) -> Circe.extract(pat)) -> Circe.extract(expr)
      )) ->
        %{
          fun: fun,
          args: args,
          pat: pat,
          expr: expr,
        }
    end

    assert result == %{
      fun: {:fruit, [], __MODULE__},
      args: [3],
      pat: {:ok, :banana},
      expr: :split,
    }
  end

  test "banana case with patterns" do
    require Circe

    ast = quote do (fruit.(3) -> {:ok, :banana}) -> :split end
    result = case ast do
      Circe.match((
        (Circe.extract({fun_name, _, _} = fun).(Circe.extract_splicing(args)) -> Circe.extract(pat)) -> Circe.extract(expr)
      )) when fun_name == :fruit ->
        %{
          fun: fun,
          args: args,
          pat: pat,
          expr: expr,
        }

      _ -> :ko
    end

    assert result == %{
      fun: {:fruit, [], __MODULE__},
      args: [3],
      pat: {:ok, :banana},
      expr: :split,
    }
  end

  test "banana case with patterns 2" do
    require Circe

    ast = quote do (fruit.(3) -> {:ok, :banana}) -> :split end
    result = case ast do
      Circe.match((
        (extract({fun_name, _, _} = fun).(extract_splicing(args)) -> extract(pat)) -> extract(expr)
      )) when fun_name == :fruit ->
        %{
          fun: fun,
          args: args,
          pat: pat,
          expr: expr,
        }

      _ -> :ko
    end

    assert result == %{
      fun: {:fruit, [], __MODULE__},
      args: [3],
      pat: {:ok, :banana},
      expr: :split,
    }
  end

  test "banana case with patterns 3" do
    require Circe

    ast = quote do (fruit.(3) -> {:ok, :banana}) -> :split end
    result = case ast do
      Circe.match((
        (@({fun_name, _, _} = fun).(~~~(args)) -> @(pat)) -> @(expr)
      )) when fun_name == :fruit ->
        %{
          fun: fun,
          args: args,
          pat: pat,
          expr: expr,
        }

      _ -> :ko
    end

    assert result == %{
      fun: {:fruit, [], __MODULE__},
      args: [3],
      pat: {:ok, :banana},
      expr: :split,
    }
  end

  test "no import case" do
    require Circe

    ast = quote do extract(:split) end
    result = case ast do
      Circe.match([import?: :disabled], extract(@(atom))) ->
        {:ok, atom}
    end

    assert result == {:ok, :split}
  end
end
