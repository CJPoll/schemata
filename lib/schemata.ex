defmodule Schemata.Compile do
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
    has_one = accumulated_attribute(module, :has_one)
    required_has_one = accumulated_attribute(module, :required_has_one)
    has_many = accumulated_attribute(module, :has_many)
    required_has_many = accumulated_attribute(module, :required_has_many)
    aliases = accumulated_attribute(module, :alias)
    belongs_to = accumulated_attribute(module, :belongs_to)

    table = Module.get_attribute(module, :table, nil)

    required_names = names(required)
    names = names(fields) ++ names(required)

    required_has_one_names = names(required_has_one)
    has_one_names = names(has_one) ++ names(required_has_one)

    required_has_many_names = names(required_has_many)
    has_many_names = names(has_many) ++ names(required_has_many)

    ast =
      Enum.map(belongs_to, fn
        [name, type] ->
          quote do
            Ecto.Schema.belongs_to(unquote(name), unquote(type))
          end

        [name, type, opts] ->
          quote do
            Ecto.Schema.belongs_to(unquote(name), unquote(type), unquote(opts))
          end

        _ ->
          []
      end) ++
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
        Enum.map(has_one ++ required_has_one, fn
          [name, type] ->
            if table do
              quote do
                Ecto.Schema.has_one(unquote(name), unquote(type))
              end
            else
              quote do
                Ecto.Schema.embeds_one(unquote(name), unquote(type))
              end
            end

          [name, type, opts] ->
            opts = Keyword.delete(opts, :required)

            if table do
              quote do
                Ecto.Schema.has_one(unquote(name), unquote(type), unquote(opts))
              end
            else
              quote do
                Ecto.Schema.embeds_one(unquote(name), unquote(type), unquote(opts))
              end
            end

          _ ->
            []
        end) ++
        Enum.map(has_many ++ required_has_many, fn
          [name, type] ->
            if table do
              quote do
                Ecto.Schema.has_many(unquote(name), unquote(type))
              end
            else
              quote do
                Ecto.Schema.embeds_many(unquote(name), unquote(type))
              end
            end

          [name, type, opts] ->
            opts = Keyword.delete(opts, :required)

            if table do
              quote do
                Ecto.Schema.has_many(unquote(name), unquote(type), unquote(opts))
              end
            else
              quote do
                Ecto.Schema.embeds_many(unquote(name), unquote(type), unquote(opts))
              end
            end
        end)

    required_embed_names = required_has_one_names ++ required_has_many_names
    all_embed_names = has_one_names ++ has_many_names

    cast_has_ast =
      cond do
        all_embed_names == [] ->
          quote do
            cs
          end

        required_embed_names == [] ->
          if table do
            quote do
              Enum.reduce(unquote(all_embed_names), cs, fn name, cs ->
                cast_assoc(cs, name)
              end)
            end
          else
            quote do
              Enum.reduce(unquote(all_embed_names), cs, fn name, cs ->
                cast_embed(cs, name)
              end)
            end
          end

        true ->
          if table do
            quote do
              Enum.reduce(unquote(all_embed_names), cs, fn
                name, cs when name in unquote(required_embed_names) ->
                  cast_assoc(cs, name, required: true)

                name, cs ->
                  cast_assoc(cs, name)
              end)
            end
          else
            quote do
              Enum.reduce(unquote(all_embed_names), cs, fn
                name, cs when name in unquote(required_embed_names) ->
                  cast_embed(cs, name, required: true)

                name, cs ->
                  cast_embed(cs, name)
              end)
            end
          end
      end

      schema =
        if table do
          quote do
            Ecto.Schema.schema(unquote(table), do: unquote(ast))
          end
        else
          quote do
            Ecto.Schema.embedded_schema(do: unquote(ast))
          end
        end

    quote do
      unquote(schema)

      use Schemata.Renderable,
        has: unquote(all_embed_names)

      def changeset(data, params) do
        import Ecto.Changeset

        params = Schemata.Params.resolve_aliases(params, unquote(aliases))

        cs =
          data
          |> cast(params, unquote(names))
          |> validate_required(unquote(required_names))

        unquote(cast_has_ast)
      end

      defoverridable [changeset: 2]

      unquote(initial)

      def new, do: %__MODULE__{}
      @type t :: %__MODULE__{}
      @type field :: atom
      @type error_message :: String.t
      @spec from_map(map) :: {:ok, t} | {:error, %{field => [error_message]}}
      def from_map(map) do
        cs = __MODULE__.changeset(__MODULE__.new(), map)

        if cs.valid? do
          {:ok, Ecto.Changeset.apply_changes(cs)}
        else
          errs =
            Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
              Enum.reduce(opts, msg, fn {key, value}, acc ->
                String.replace(acc, "%{#{key}}", to_string(value))
              end)
            end)

          {:error, errs}
        end
      end
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

      {:defschema, meta, [{:__aliases__, meta, right}, [table: table], [do: block]]} ->
        {:defschema, meta, [{:__aliases__, meta, Enum.concat(left, right)}, [table: table], [do: block]]}

      {:defmodule, meta, [{:__aliases__, meta, right}, [do: block]]} ->
        {:defschema, meta, [{:__aliases__, meta, Enum.concat(left, right)}, [do: block]]}

      {:namespaced, _, [{:__aliases__, meta, right}]} ->
        {:__aliases__, meta, Enum.concat(left, right)}

      other ->
        other
    end)
  end

  defmacro deffields(table, do: block) do
    Module.put_attribute(__CALLER__.module, :table, table)

    quote do
      unquote(__MODULE__).deffields(do: unquote(block))
    end
  end
  defmacro deffields(do: block) do
    Module.register_attribute(__CALLER__.module, :fields, accumulate: true)
    Module.register_attribute(__CALLER__.module, :required, accumulate: true)
    Module.register_attribute(__CALLER__.module, :has_one, accumulate: true)
    Module.register_attribute(__CALLER__.module, :required_has_one, accumulate: true)
    Module.register_attribute(__CALLER__.module, :has_many, accumulate: true)
    Module.register_attribute(__CALLER__.module, :required_has_many, accumulate: true)
    Module.register_attribute(__CALLER__.module, :aliases, accumulate: true)
    Module.register_attribute(__CALLER__.module, :belongs_to, accumulate: true)

    {ast, _} = Macro.prewalk(block, __CALLER__.module, &handle_node/2)
    __MODULE__.Compile.do_compile(__CALLER__.module, ast)
  end

  def handle_node({:field, _meta, [name, type, opts]}, module) do
    required = Keyword.get(opts, :required, false)

    if alias = Keyword.get(opts, :alias, nil) do
      unless is_atom(alias) do
        raise "alias #{inspect alias} for field #{inspect name} of #{inspect module} must be an atom, not a string"
      end
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
      when embed in [:has_one, :has_many] and is_list(opts) do
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

  def handle_node({embed, _meta, args}, module) when embed in [:has_one, :has_many] do
    Module.put_attribute(module, embed, args)
    {nil, module}
  end

  def handle_node({:belongs_to, meta, [name, queryable]}, module) do
    handle_node({:belongs_to, meta, [name, queryable, []]}, module)
  end

  def handle_node({:belongs_to, _meta, args}, module) do
    table = Module.get_attribute(module, :table, nil)

    if table do
      Module.put_attribute(module, :belongs_to, args)
      {nil, module}
    else
      raise "#{inspect module} has defined a belongs_to association, but is an embedded_schema."
    end
  end

  def handle_node(node, module), do: {node, module}

  defp sanitize(opts) do
    opts
    |> Keyword.delete(:required)
    |> Keyword.delete(:alias)
  end

  defmacro defschema(module, opts \\ [], [do: block]) do
    if table = Keyword.get(opts, :table, false) do
      quote do
        defmodule unquote(module) do
          use Ecto.Schema
          import Ecto.Changeset

          unquote(__MODULE__).deffields(unquote(table), do: unquote(block))
        end
      end
    else
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
end

defmodule Schemata.Params do
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
    Enum.reduce(aliases, params, fn({alias, name}, acc) ->
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

  defp rename_key(map, old, new) do
    map
    |> Map.update(new, map[old], fn(_) -> map[old] end)
    |> Map.delete(old)
  end
end
