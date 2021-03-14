defmodule Circe do
  @moduledoc """
  Documentation for `Circe`.
  """

  defmacro match(opts \\ [], ast) do
    {match_ast, _metas} = process_input(ast, opts)

    match_ast
    |> case do x -> _ = IO.puts("match:\n#{Macro.to_string(x)}") ; x end
  end

  def process_input(ast, opts) do
    import_enabled? = case Keyword.get(opts, :import?, :enabled) do
      :enabled -> :import_enabled
      :disabled -> :operator_disabled
    end

    operator_enabled? = case Keyword.get(opts, :operator?, :enabled) do
      :enabled -> :operator_enabled
      :disabled -> :operators_disabled
    end

    ast = case Keyword.get(opts, :strip_list, false) do
      true -> [ast] = ast ; ast
      false -> ast
    end

    {prepared_ast, metas} =
      prepare_ast(ast, import_enabled?, operator_enabled?)

    var_by_escaped =
      Map.new(metas, fn meta -> {Macro.escape(meta.ast), meta.var} end)

    match_ast =
      replace_escaped(Macro.escape(prepared_ast), var_by_escaped)

    {match_ast, metas}
  end

  @doc false
  def prepare_ast([{{:., _, [{:__aliases__, _, [:Circe]}, :extract_splicing]}, _, [var]}] = ast, _, _) do
    {ast, [%{var: var, ast: ast}]}
  end

  def prepare_ast([{:extract_splicing, _, [var]}] = ast, :import_enabled, _) do
    {ast, [%{var: var, ast: ast}]}
  end

  def prepare_ast({{:., _, [{:__aliases__, _, [:Circe]}, :extract]}, _, [var]} = ast, _, _) do
    {ast, [%{var: var, ast: ast}]}
  end

  def prepare_ast({:extract, _, [var]} = ast, :import_enabled, _) do
    {ast, [%{var: var, ast: ast}]}
  end

  def prepare_ast([{:~~~, _, [var]}] = ast, _, :operator_enabled) do
    {ast, [%{var: var, ast: ast}]}
  end

  def prepare_ast({:@, _, [var]} = ast, _, :operator_enabled) do
    {ast, [%{var: var, ast: ast}]}
  end

  def prepare_ast({left, _meta, right}, import?, operator?) do
    {ast_l, metas_l} = prepare_ast(left, import?, operator?)
    {ast_r, metas_r} = prepare_ast(right, import?, operator?)
    {{ast_l, :"$to_ignore", ast_r}, metas_l ++ metas_r}
  end

  def prepare_ast(xs, import?, operator?) when is_list(xs) do
    Enum.unzip(Enum.map(xs, fn x -> prepare_ast(x, import?, operator?) end))
    |> case do {ast, metass} -> {ast, Enum.concat(metass)} end
  end

  def prepare_ast(x, _, _) when is_atom(x) do
    {x, []}
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

        :"$to_ignore" -> Macro.var(:_, nil)

        x -> x
      end
    end
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
