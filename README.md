# Circe

Enchantress expert at transformation.

This library aims at providing convenient tool for manipulating Elixir's AST.
Currently there is only a sigil macro that help defining patterns in more declarative way.

A few quick examples:
```elixir
iex(1)> import Circe
Circe
iex(2)> ~m/{:banana}/ = quote do {:banana} end
{:{}, [], [:banana]}
iex(3)> ~m/{#{x}}/ = quote do {:banana} end
{:{}, [], [:banana]}
iex(4)> ~m/{#{x}}/ = quote do {:banana, :split, :dessert} end
** (MatchError) no match of right hand side value: {:{}, [], [:banana, :split, :dessert]}

iex(4)> ~m/{#{...xs}}/ = quote do {:banana} end
{:{}, [], [:banana]}
iex(5)> xs
[:banana]
iex(6)> ~m/{#{x}}/ = quote do {:banana, :split} end
** (MatchError) no match of right hand side value: {:banana, :split}

iex(6)> ~m/{#{...x}}/ = quote do {:banana, :split} end
** (MatchError) no match of right hand side value: {:banana, :split}

```

As can be seen from the last two examples, it's not yet possible to match on ast that can be literals
when it's representation could also be an application. In the case here:
* 2-tuples are represented literally: `{:banana, :split} = quote do {:banana, :split}` end
* n-typles (where n ≠ 2) are represented as an application `{:{}, _, xs} when is_list(xs) = quote do {:a, :b, :c, :d} end`

```elixir
iex(8)> ~m/{#{x}, #{y}}/ = quote do {:banana, :split} end    
** (CaseClauseError) no case clause matching: {{:circe_match_0, [line: 8], nil}, {:circe_match_1, [line: 8], nil}}
    (circe 0.1.0) lib/circe.ex:223: Circe.preprocess/2
    (circe 0.1.0) expanding macro: Circe.sigil_m/2
    iex:8: (file)
```
The above example is a problem in the library.
