defmodule Schemata.Params do
  @moduledoc false
  def resolve_aliases(params, aliases) when is_list(aliases) do
    aliases =
      aliases
      |> Enum.map(fn
        [k, v] -> {k, v}
        {_k, _v} = kv -> kv
      end)
      |> Map.new()

    resolve_aliases(params, aliases)
  end

  def resolve_aliases(params, aliases) when is_map(aliases) do
    Enum.reduce(aliases, params, fn {alias, name}, acc ->
      cond do
        Map.has_key?(acc, alias) ->
          rename_key(acc, alias, name)

        Map.has_key?(acc, str = Atom.to_string(alias)) ->
          rename_key(acc, str, Atom.to_string(name))

        true ->
          acc
      end
    end)
  end

  def atom_keys_to_string(map) when is_map(map) do
    map
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      other -> other
    end)
    |> Map.new()
  end

  def rename_key(map, old, new) do
    map
    |> Map.update(new, map[old], fn _ -> map[old] end)
    |> Map.delete(old)
  end

  def delete_key(params, key) when is_atom(key) do
    params
    |> atom_keys_to_string
    |> Map.delete(Atom.to_string(key))
  end
end
