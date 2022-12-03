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

As can be seen from the last two examples, it's not yet possible to match on asts that can be literals
when it's representation could also be an application. In the case here:
* 2-tuples are represented literally: `{:banana, :split} = quote do {:banana, :split}` end
* n-tuples (where n ≠ 2) are represented as an application `{:{}, _, xs} when is_list(xs) = quote do {:a, :b, :c, :d} end`

No idea how to do that natively, we would need a way to merge multiple patterns into one.
It should be possible with pattern synonyms though. (You can take a look at the package `pattern_metonyms`.)
