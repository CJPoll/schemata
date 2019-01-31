defmodule Schemata.Schema.Compile do
  @moduledoc false
  def names(list) do
    Enum.map(list, fn
      [name, _] -> name
      [name, _, _] -> name
    end)
  end

  def accumulated_attribute(module, name) do
    case Module.get_attribute(module, name, []) do
      list when is_list(list) ->
        if Enum.all?(list, &is_list/1), do: list, else: [list]

      nil ->
        []

      other ->
        [other]
    end
  end

  def do_compile(module, initial) do
    fields = accumulated_attribute(module, :fields)
    required = accumulated_attribute(module, :required)
    embeds_one = accumulated_attribute(module, :embeds_one)
    required_embeds_one = accumulated_attribute(module, :required_embeds_one)
    embeds_many = accumulated_attribute(module, :embeds_many)
    required_embeds_many = accumulated_attribute(module, :required_embeds_many)
    aliases = accumulated_attribute(module, :alias)

    required_names = names(required)
    names = names(fields) ++ names(required)

    required_embeds_one_names = names(required_embeds_one)
    embeds_one_names = names(embeds_one) ++ names(required_embeds_one)

    required_embeds_many_names = names(required_embeds_many)
    embeds_many_names = names(embeds_many) ++ names(required_embeds_many)

    ast =
      Enum.map(fields ++ required, fn
        [name, type] ->
          quote do
            Ecto.Schema.field(unquote(name), unquote(type))
          end

        [name, type, opts] ->
          quote do
            Ecto.Schema.field(unquote(name), unquote(type), unquote(opts))
          end

        _ ->
          []
      end) ++
        Enum.map(embeds_one ++ required_embeds_one, fn
          [name, type] ->
            quote do
              Ecto.Schema.embeds_one(unquote(name), unquote(type))
            end

          [name, type, opts] ->
            opts = Keyword.delete(opts, :required)

            quote do
              Ecto.Schema.embeds_one(unquote(name), unquote(type), unquote(opts))
            end

          _ ->
            []
        end) ++
        Enum.map(embeds_many ++ required_embeds_many, fn
          [name, type] ->
            quote do
              Ecto.Schema.embeds_many(unquote(name), unquote(type))
            end

          [name, type, opts] ->
            opts = Keyword.delete(opts, :required)

            quote do
              Ecto.Schema.embeds_many(unquote(name), unquote(type), unquote(opts))
            end
        end)

    required_embed_names = required_embeds_one_names ++ required_embeds_many_names
    all_embed_names = embeds_one_names ++ embeds_many_names

    cast_embeds_ast =
      cond do
        all_embed_names == [] ->
          quote do
            cs
          end

        required_embed_names == [] ->
          quote do
            Enum.reduce(unquote(all_embed_names), cs, fn name, cs ->
              cast_embed(cs, name)
            end)
          end

        true ->
          quote do
            Enum.reduce(unquote(all_embed_names), cs, fn
              name, cs when name in unquote(required_embed_names) ->
                cast_embed(cs, name, required: true)

              name, cs ->
                cast_embed(cs, name)
            end)
          end
      end

    quote do
      Ecto.Schema.embedded_schema(do: unquote(ast))

      use Schemata.PreQual.CreditCards.Amex.Renderable,
        embeds: unquote(all_embed_names)

      def changeset(data, params) do
        import Ecto.Changeset

        params = Schemata.Schema.Params.resolve_aliases(params, unquote(aliases))

        cs =
          data
          |> cast(params, unquote(names))
          |> validate_required(unquote(required_names))

        unquote(cast_embeds_ast)
      end

      defoverridable [changeset: 2]

      unquote(initial)

      def new, do: %__MODULE__{}
    end
  end
end

defmodule Schemata do
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro defnamespace({:__aliases__, _, left}, do: block) do
    Macro.prewalk(block, fn
      {:defschema, meta, [{:__aliases__, meta, right}, [do: block]]} ->
        {:defschema, meta, [{:__aliases__, meta, Enum.concat(left, right)}, [do: block]]}

      {:namespaced, _, [{:__aliases__, meta, right}]} ->
        {:__aliases__, meta, Enum.concat(left, right)}

      other ->
        other
    end)
  end

  defmacro deffields(do: block) do
    Module.register_attribute(__CALLER__.module, :fields, accumulate: true)
    Module.register_attribute(__CALLER__.module, :required, accumulate: true)
    Module.register_attribute(__CALLER__.module, :embeds_one, accumulate: true)
    Module.register_attribute(__CALLER__.module, :required_embeds_one, accumulate: true)
    Module.register_attribute(__CALLER__.module, :embeds_many, accumulate: true)
    Module.register_attribute(__CALLER__.module, :required_embeds_many, accumulate: true)
    Module.register_attribute(__CALLER__.module, :aliases, accumulate: true)

    {ast, _} = Macro.prewalk(block, __CALLER__.module, &handle_node/2)
    __MODULE__.Compile.do_compile(__CALLER__.module, ast)
  end

  def handle_node({:field, _meta, [name, type, opts]}, module) do
    required = Keyword.get(opts, :required, false)

    if alias = Keyword.get(opts, :alias, nil) do
      Module.put_attribute(module, :alias, [alias, name])
    end

    if required do
      opts = sanitize(opts)

      Module.put_attribute(module, :required, [name, type, opts])
    else
      opts = sanitize(opts)

      Module.put_attribute(module, :fields, [name, type, opts])
    end

    {nil, module}
  end

  def handle_node({:field, _meta, [name, type]}, module) do
    Module.put_attribute(module, :fields, [name, type])

    {nil, module}
  end

  def handle_node({embed, _meta, [name, type, opts]}, module)
      when embed in [:embeds_one, :embeds_many] and is_list(opts) do
    if alias = Keyword.get(opts, :alias, nil) do
      Module.put_attribute(module, :alias, [alias, name])
    end

    if Keyword.get(opts, :required, false) do
      opts = sanitize(opts)
      args = [name, type, opts]
      Module.put_attribute(module, :"required_#{embed}", args)
    else
      opts = sanitize(opts)
      args = [name, type, opts]
      Module.put_attribute(module, embed, args)
    end

    {nil, module}
  end

  def handle_node({embed, _meta, args}, module) when embed in [:embeds_one, :embeds_many] do
    Module.put_attribute(module, embed, args)
    {nil, module}
  end

  def handle_node(node, module), do: {node, module}

  defp sanitize(opts) do
    opts
    |> Keyword.delete(:required)
    |> Keyword.delete(:alias)
  end

  defmacro defschema(module, do: block) do
    quote do
      defmodule unquote(module) do
        use Ecto.Schema
        import Ecto.Changeset

        @primary_key false

        unquote(__MODULE__).deffields(do: unquote(block))
      end
    end
  end
end

defmodule Schemata.Schema.Params do
  @moduledoc false
  def resolve_aliases(params, aliases) when is_list(aliases) do
    aliases =
      aliases
      |> Enum.map(fn
        ([k, v]) -> {k, v}
        ({_k, _v} = kv) -> kv
      end)
      |> Map.new

    resolve_aliases(params, aliases)
  end

  def resolve_aliases(params, aliases) when is_map(aliases) do
    params
    |> Enum.map(fn({k, v} = kv) ->
      cond do
        Map.has_key?(aliases, k) ->
          {aliases[k], v}
        Map.has_key?(aliases, Atom.to_string(k)) ->
          {aliases[Atom.to_string(k)], v}
        true ->
          kv
      end
    end)
    |> Map.new
  end
end
