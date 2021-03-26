defmodule Circe do
  @moduledoc """
  Documentation for `Circe`.
  """

  defmacro match(opts \\ [], ast) do
    {match_ast, _metas} = process_input(ast, opts)

    match_ast
    #|> case do x -> _ = IO.puts("match:\n#{Macro.to_string(x)}") ; x end
  end

  defmacrop spliced(pat) do
    quote do
      {:"::", _, [{{:., _, [Kernel, :to_string]}, _, [[spliced: unquote(pat)]]}, _]}
    end
  end

  defmacrop singleton(pat) do
    quote do
      {:"::", _, [{{:., _, [Kernel, :to_string]}, _, [unquote(pat)]}, _]}
    end
  end

  defmacrop qualified_extract_splicing(var) do
    quote do
      [{{:., _, [{:__aliases__, _, [:Circe]}, :extract_splicing]}, _, [unquote(var)]}]
    end
  end

  def to_qualified_extract_splicing(var) do
    [{{:., [], [{:__aliases__, [], [:Circe]}, :extract_splicing]}, [], [var]}]
  end

  defmacrop qualified_extract(var) do
    quote do
      {{:., _, [{:__aliases__, _, [:Circe]}, :extract]}, _, [unquote(var)]}
    end
  end

  def to_qualified_extract(var) do
    {{:., [], [{:__aliases__, [], [:Circe]}, :extract]}, [], [var]}
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
      #|> IO.inspect(label: "prepare_ast")

    var_by_escaped =
      Map.new(metas, fn meta -> {Macro.escape(meta.ast), meta.var} end)
      #|> IO.inspect(label: "var_by_escaped")

    match_ast =
      replace_escaped(Macro.escape(prepared_ast), var_by_escaped)
      #|> IO.inspect(label: "replace_escaped")

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

  # do block
  def prepare_ast({:do, x}, import?, operator?) do
    {ast, metas} = prepare_ast(x, import?, operator?)
    {{:do, ast}, metas}
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

        {:do, x} -> # do block
          {:do, replace_escaped(x, m)}

        :"$to_ignore" -> Macro.var(:_, nil)

        x -> x
      end
    end
  end

  defmacro sigil_m({:<<>>, _, term}, modifiers) do
    #_ = IO.inspect(modifiers, label: "#{__MODULE__} -- modifiers")
    #_ = IO.inspect(term, label: "#{__MODULE__} -- term")

    opts = Enum.flat_map(modifiers, fn
      ?w -> [strip_list: true]
      _ -> []
    end)

    opts = Map.to_list(Map.merge(%{import?: :disabled, operator?: :disabled}, Map.new(opts)))

    fallback_clause = quote do _ -> :no_match end
    {iodata, {_n, match_ast}} = Enum.map_reduce(term, {0, fallback_clause}, fn
      spliced(pat), {n, xs} ->
        tmp_name = :"circe_match_#{n}"
        match_ast = quote do [{unquote(tmp_name), _, _}] -> {:ok, unquote(Macro.escape(to_qualified_extract_splicing(pat)))} end
        {to_string(tmp_name), {n + 1, match_ast ++ xs}}

      singleton(pat), {n, xs} ->
        tmp_name = :"circe_match_#{n}"
        match_ast = quote do
          {unquote(tmp_name), _, ast} ->
            #IO.puts("MATCHED TUPLE")
            disambiguate = fn
              ^ast -> unquote(Macro.escape(to_qualified_extract(pat)))
              new_ast -> {unquote(Macro.escape(to_qualified_extract(pat))), [], new_ast}
            end
            {:ambiguous, ast, disambiguate}

          unquote(tmp_name) -> {:ok, unquote(Macro.escape(to_qualified_extract(pat)))}
        end
        {to_string(tmp_name), {n + 1, match_ast ++ xs}}

      x, acc ->
        {x, acc}
    end)

    {matcher, _} = Code.eval_quoted({:fn, [], match_ast})

    ast = Code.string_to_quoted!(IO.iodata_to_binary(iodata), file: __CALLER__.file, line: __CALLER__.line)
          #|> IO.inspect(label: "string_to_quoted result --")

    preprocess(ast, matcher)
    #|> IO.inspect(label: "preprocessed ast")
    #|> case do x -> IO.puts("preprocessed -- #{Macro.to_string(x)}") ; x end
    |> process_input(opts)
    |> case do {match_ast, _} -> match_ast end
    #|> IO.inspect(label: "processed ast")
    #|> case do x -> IO.puts("processed -- #{Macro.to_string(x)}") ; x end
  end

  def preprocess(ast, matcher) do
    case matcher.(ast) do
      {:ok, ast} -> ast

      {:ambiguous, sub_ast, finalize} ->
        finalize.(preprocess(sub_ast, matcher))
        #|> IO.inspect(label: "FINALIZED AS")

      :no_match -> case ast do
        {left, meta, right} ->
          ast_left = preprocess(left, matcher)
          ast_right = preprocess(right, matcher)
          {ast_left, meta, ast_right}

        xs when is_list(xs) ->
          Enum.map(xs, fn x -> preprocess(x, matcher) end)

        {:do, x} -> # do block
          {:do, preprocess(x, matcher)}

        x when is_atom(x) -> x
      end
    end
  end

  ### Other ###

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
