defmodule Circe do
  @moduledoc """
  Documentation for `Circe`.
  """

  defmacro input(ast) do
    #_ = IO.puts("input(ast) = #{inspect(ast)}")
    #_ = IO.puts("input(code) = #{Macro.to_string(ast)}")
    #_ = IO.puts("input(escaped ast) = #{inspect(Macro.escape(ast))}")
    #_ = IO.puts("input(escaped code) = #{Macro.to_string(Macro.escape(ast))}")

    ast = Macro.prewalk(ast, fn
      {l, _, r} -> {l, :"$to_ignore", r}
      x -> x
    end)

    meta_by_name =
      traverse_ast(ast)
      |> Map.new(fn {name, m} -> {name, put_in(m, [:var, Access.elem(1)], [])} end)

    #_ = IO.inspect(meta_by_name, label: "traverse_ast result", syntax_colors: default_color())

    var_by_escaped = Map.new(meta_by_name, fn {_name, meta} -> {Macro.escape(meta.ast), meta.var} end)

    match_ast = replace_escaped(Macro.escape(ast), var_by_escaped)
    match_ast = Macro.prewalk(match_ast, fn
      :"$to_ignore" -> Macro.var(:_, nil)
      x -> x
    end)
    #|> IO.inspect(label: "match_ast")

    #_ = IO.puts("match_ast: #{Macro.to_string(match_ast)}")

    result_ast = {:%{}, [], Enum.map(meta_by_name, fn {name, meta} -> {name, put_elem(meta.var, 1, [])} end)}
    #             |> IO.inspect(label: "result_ast")

    #_ = IO.puts("result_ast: #{Macro.to_string(result_ast)}")

    quote do
      fn
        unquote(match_ast) -> {:ok, unquote(result_ast)}
        _ -> {:error, :no_match}
      end
    end
    #|> case do x -> _ = IO.puts("input:\n#{Macro.to_string(x)}") ; x end
  end

  @doc false
  def traverse_ast([{{:., _, [{:__aliases__, _, [:Circe]}, :extract_splicing]}, _, [{name, _, nil} = var]}] = ast) do
    %{name => %{var: var, ast: ast}}
  end

  def traverse_ast([{:extract_splicing, _, [{name, _, nil} = var]}] = ast) do
    %{name => %{var: var, ast: ast}}
  end

  def traverse_ast({{:., _, [{:__aliases__, _, [:Circe]}, :extract]}, _, [{name, _, nil} = var]} = ast) do
    %{name => %{var: var, ast: ast}}
  end

  def traverse_ast({:extract, _, [{name, _, nil} = var]} = ast) do
    %{name => %{var: var, ast: ast}}
  end

  def traverse_ast({left, _meta, right}) do
    Map.merge(traverse_ast(left), traverse_ast(right))
  end

  def traverse_ast(xs) when is_list(xs) do
    Enum.map(xs, &traverse_ast/1)
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  def traverse_ast(x) when is_atom(x) do
    %{}
  end

  def replace_escaped(escaped_ast, m) do
    case Map.fetch(m, escaped_ast) do
      {:ok, ast} -> ast
      :error -> case escaped_ast do
        {left, meta, right} ->
          left = replace_escaped(left, m)
          right = replace_escaped(right, m)
          {left, meta, right}

        xs when is_list(xs) ->
          Enum.map(xs, fn x -> replace_escaped(x, m) end)

        x -> x
      end
    end
  end

  defmacro output(_ast) do
    #_ = IO.puts("output(ast) = #{inspect(ast)}")
    #_ = IO.puts("output(code) = #{Macro.to_string(ast)}")
    nil
  end


  @doc false
  def default_color do
    [
      atom: :cyan,
      string: :green,
      list: :default_color,
      boolean: :magenta,
      nil: :magenta,
      tuple: :default_color,
      binary: :default_color,
      map: :default_color
    ]
  end
end

# iex(16)> quote do Circe.extract({:., _, [{:__aliases__, _, [:Banana]}, fun]} = module when fun in [:split, :puree]) end
# {{:., [], [{:__aliases__, [alias: false], [:Circe]}, :extract]}, [],
#  [
#    {:when, [],
#     [
#       {:=, [],
#        [
#          {:{}, [],
#           [
#             :.,
#             {:_, [], Elixir},
#             [
#               {:{}, [], [:__aliases__, {:_, [], Elixir}, [:Banana]]},
#               {:fun, [], Elixir}
#             ]
#           ]},
#          {:module, [], Elixir}
#        ]},
#       {:in, [context: Elixir, import: Kernel],
#        [{:fun, [], Elixir}, [:split, :puree]]}
#     ]}
#  ]}
