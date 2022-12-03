defmodule Circe do
  @moduledoc """
  Documentation for `Circe`.
  """

  defmacrop tridot(pat) do
    quote do
      {:"::", _, [{{:., _, [Kernel, :to_string]}, _, [{:..., _, [unquote(pat)]}]}, _]}
    end
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

  @doc false
  def extract_splicing(var) do
    [{:"$Circe.extract_splicing", [], [var]}]
  end

  @doc false
  def extract(var) do
    {:"$Circe.extract", [], [var]}
  end

  @doc false
  def process_input(ast, opts) do
    ast = case Keyword.get(opts, :unwrap_list, false) do
      false -> ast
      true -> case ast do
        [ast] -> ast
        _ -> raise("Attempted to unwrap a non wrapped ast")
      end
    end

    {prepared_ast, metas} =
      prepare_ast(ast)
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
  def prepare_ast([{:"$Circe.extract_splicing", _, [var]}] = ast) do
    {ast, [%{var: var, ast: ast}]}
  end

  def prepare_ast({:"$Circe.extract", _, [var]} = ast) do
    {ast, [%{var: var, ast: ast}]}
  end

  def prepare_ast({left, _meta, right}) do
    {ast_l, metas_l} = prepare_ast(left)
    {ast_r, metas_r} = prepare_ast(right)
    {{ast_l, :"$to_ignore", ast_r}, metas_l ++ metas_r}
  end

  def prepare_ast(xs) when is_list(xs) do
    Enum.unzip(Enum.map(xs, &prepare_ast/1))
    |> case do {ast, metass} -> {ast, Enum.concat(metass)} end
  end

  def prepare_ast({x, y}) do
    {ast, metas} = prepare_ast(x)
    {ast2, metas2} = prepare_ast(y)
    {{ast, ast2}, metas ++ metas2}
  end

  def prepare_ast(x) when is_atom(x) do
    {x, []}
  end

  @doc false
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

        {x, y} ->
          {replace_escaped(x, m), replace_escaped(y, m)}

        :"$to_ignore" -> Macro.var(:_, nil)

        x -> x
      end
    end
  end

  @doc ~S"""
  Handles the sigil `~m` to match on code's ast.

  This is meant as a symmetric tool to `quote/2`.

  The sigil should be used within a matching context:
  - `case/2` clause
  - function head (`def/2` and `fn/1`)
  - `=/2` left hand side
  - `match?/2`'s first argument

  You can directly match code:
      iex> import Circe
      iex> ast = quote do {:banana} end
      {:{}, [], [:banana]}
      iex> match?(~m/{:banana}/, ast)
      true

  You can ignore parts of the code by combining interpolation and an underscore:
      iex> import Circe
      iex> ast = quote do {:test_atom_pls_ignore} end
      {:{}, [], [:test_atom_pls_ignore]}
      iex> match?(~m/{#{_}}/, ast)
      true

  Instead of ignoring parts of the code, you can bind it to a variable:
      iex> import Circe
      iex> ~m/{#{banana}}/ = quote do {:split} end
      {:{}, [], [:split]}
      iex> banana
      :split

  Sometime the ast that would correspond to the code you wrote is wrapped in a list,
  (typically concerning the `->` operator), you can unwrap it with the modifier `w`:
      iex> import Circe
      iex> ast = quote do case 4 do 1 -> :one ; 2 -> :two ; 3 -> :three ; _ -> :too_big end end
      iex> ~m/case #{_} do #{clauses} end/ = ast
      iex> Enum.any?(clauses, fn ~m/(#{_} -> :too_big)/ -> true ; _ -> false end)
      false
      iex> Enum.any?(clauses, fn ~m/(#{_} -> :too_big)/w -> true ; _ -> false end)
      true

  The equivalent to `unquote_splicing/3` is `#{..._}`:
      iex> import Circe
      iex> ~m/{#{...desserts}}/ = quote do {:banana, :split, :peach, :melba} end
      {:{}, [], [:banana, :split, :peach, :melba]}
      iex> desserts
      [:banana, :split, :peach, :melba]
  """
  defmacro sigil_m({:<<>>, _, term}, modifiers) do
    #_ = IO.inspect(modifiers, label: "#{__MODULE__} -- modifiers")
    #_ = IO.inspect(term, label: "#{__MODULE__} -- term")

    opts = Enum.flat_map(modifiers, fn
      ?w -> [unwrap_list: true]
      _ -> []
    end)

    fallback_clause = quote do _ -> :no_match end
    {iodata, {_n, match_ast}} = Enum.map_reduce(term, {0, fallback_clause}, fn
      tridot(pat), {n, xs} ->
        tmp_name = :"circe_match_#{n}"
        match_ast = quote do [{unquote(tmp_name), _, _}] -> {:ok, unquote(Macro.escape(extract_splicing(pat)))} end
        {to_string(tmp_name), {n + 1, match_ast ++ xs}}

      spliced(pat), {n, xs} ->
        stacktrace = [{__MODULE__, :sigil_m, 2, [file: to_charlist(__CALLER__.file), line: __CALLER__.line]}]
        _ = IO.warn("[spliced: #{Macro.to_string(pat)}] is deprecated in favor of ...#{Macro.to_string(pat)}", stacktrace)
        tmp_name = :"circe_match_#{n}"
        match_ast = quote do [{unquote(tmp_name), _, _}] -> {:ok, unquote(Macro.escape(extract_splicing(pat)))} end
        {to_string(tmp_name), {n + 1, match_ast ++ xs}}

      singleton(pat), {n, xs} ->
        tmp_name = :"circe_match_#{n}"
        match_ast = quote do
          {unquote(tmp_name), _, ast} ->
            #IO.puts("MATCHED TUPLE")
            disambiguate = fn
              ^ast -> unquote(Macro.escape(extract(pat)))
              new_ast -> {unquote(Macro.escape(extract(pat))), [], new_ast}
            end
            {:ambiguous, ast, disambiguate}

          unquote(tmp_name) -> {:ok, unquote(Macro.escape(extract(pat)))}
        end
        {to_string(tmp_name), {n + 1, match_ast ++ xs}}

      x, acc ->
        {x, acc}
    end)

    {matcher, _} = Code.eval_quoted({:fn, [], match_ast})

    #matcher |> case do x -> IO.puts("matcher -- #{Macro.to_string({:fn, [], match_ast})}") ; x end

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

  @doc false
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

        {x, y} ->
          {preprocess(x, matcher), preprocess(y, matcher)}

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
