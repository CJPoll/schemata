defmodule Schemata.Renderable do
  @moduledoc """
  A module with generic functions for turning ecto schemas into raw maps.

  When `use`-ed, defines a `to_map/1` function in the calling module which
  defers to `to_map` in this module.
  """
  defmacro __using__(opts) do
    embeds = Keyword.get(opts, :embeds, [])

    quote do
      @doc """
      Given a struct of type t(), returns a raw map (not a struct) with all ecto
      metadata removed. Recursively calls this on all embeds and associations.
      """
      @spec to_map(t()) :: %{field => term}
      defdelegate to_map(schema), to: unquote(__MODULE__)
      defdelegate to_map(schema, opts), to: unquote(__MODULE__)

      @doc false
      def __embeds__() do
        unquote(embeds)
      end
    end
  end

  @doc """
  Given an ecto schema, returns a raw map (not a struct) with all ecto
  metadata removed. Recursively calls this on all embeds and associations.
  """
  @spec to_map(nil | Ecto.Schema.t() | [Ecto.Schema.t()]) :: map() | [map()]
  def to_map(data, opts \\ [])

  def to_map(nil, _), do: nil

  def to_map(renderables, opts) when is_list(renderables),
    do: Enum.map(renderables, &to_map(&1, opts))

  def to_map(renderable, opts) do
    kvs =
      renderable
      |> Map.from_struct()
      |> Map.delete(:__meta__)
      |> Enum.map(fn {k, v} = e ->
        if k in renderable.__struct__.__embeds__() do
          {k, unquote(__MODULE__).to_map(v)}
        else
          e
        end
      end)

    kvs =
      if Keyword.get(opts, :render_nil, true) do
        kvs
      else
        Enum.reject(kvs, fn
          {_k, nil} -> true
          _ -> false
        end)
      end

    Map.new(kvs)
  end
end
