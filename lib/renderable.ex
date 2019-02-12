defmodule Schemata.Renderable do
  defmacro __using__(opts) do
    embeds = Keyword.get(opts, :embeds, [])
    quote do
      @doc """
      Given a struct of type t(), returns a raw map (not a struct) with all ecto
      metadata removed. Recursively calls this on all embeds and associations.
      """
      @spec to_map(t()) :: %{field => term}
      defdelegate to_map(schema), to: unquote(__MODULE__)

      @doc false
      def __embeds__() do
        unquote(embeds)
      end
    end
  end

  def to_map(nil), do: nil
  def to_map(renderables) when is_list(renderables), do: Enum.map(renderables, &to_map/1)
  def to_map(renderable) do
    renderable
    |> Map.from_struct
    |> Map.delete(:__meta__)
    |> Enum.map(fn({k, v} = e) ->
        if k in renderable.__struct__.__embeds__() do
          {k, unquote(__MODULE__).to_map(v)}
        else
          e
        end
    end)
    |> Map.new
  end

  def render_all(renderables) do
    Enum.map(renderables, &to_map/1)
  end
end
