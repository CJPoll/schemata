defmodule Schemata do
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import unquote(__MODULE__)
      require Schemata.Queries
      import Schemata.Queries
      import Ecto.Query
      import Ecto.Changeset
      
      @behaviour Ecto.Type
      def type, do: :schemata_virtual_type
      def cast(_), do: :error
      def dump(_), do: :error
      def load(_), do: :error
    end
  end

  def handle_node({:field, _meta, [name, type, opts]}, module) do
    required = Keyword.get(opts, :required, false)

    if alias = Keyword.get(opts, :alias, nil) do
      unless is_atom(alias) do
        raise "alias #{inspect(alias)} for field #{inspect(name)} of #{inspect(module)} must be an atom, not a string"
      end

      Module.put_attribute(module, :aliases, {alias, name})
    end

    opts = sanitize(opts)

    ast =
      quote do
        Ecto.Schema.field(unquote(name), unquote(type), unquote(opts))
      end

    if required do
      Module.put_attribute(module, :required, {name, type, opts})
    else
      Module.put_attribute(module, :fields, {name, type, opts})
    end

    {ast, module}
  end

  def handle_node({:field, _meta, [name, type]}, module) do
    Module.put_attribute(module, :fields, {name, type})

    ast =
      quote do
        Ecto.Schema.field(unquote(name), unquote(type))
      end

    {ast, module}
  end

  def handle_node({:timestamps, _meta, args}, module) do
    Module.put_attribute(module, :timestamps, List.to_tuple(args))

    ast =
      quote do
        Ecto.Schema.timestamps(unquote(List.flatten(args)))
      end

    {ast, module}
  end

  def handle_node({embed, _meta, [name, type, opts]}, module)
      when embed in [:has_one, :has_many, :many_to_many] and is_list(opts) do
    if alias = Keyword.get(opts, :alias, nil) do
      Module.put_attribute(module, :aliases, {alias, name})
    end

    required = Keyword.get(opts, :required, false)

    opts = sanitize(opts)
    args = [name, type, opts]

    if required do
      Module.put_attribute(module, :"required_#{embed}", List.to_tuple(args))
    else
      Module.put_attribute(module, embed, List.to_tuple(args))
    end

    table = Module.get_attribute(module, :table, false)

    embeds = %{has_one: :embeds_one, has_many: :embeds_many}

    ast =
      if table do
        quote do
          require Ecto.Schema
          Ecto.Schema.unquote(embed)(unquote_splicing(args))
        end
      else
        quote do
          require Ecto.Schema
          Ecto.Schema.unquote(embeds[embed])(unquote_splicing(args))
        end
      end

    {ast, module}
  end

  def handle_node({embed, _meta, args}, module)
      when embed in [:has_one, :has_many, :many_to_many] do
    Module.put_attribute(module, embed, List.to_tuple(args))

    table = Module.get_attribute(module, :table, false)

    embeds = %{has_one: :embeds_one, has_many: :embeds_many}

    ast =
      if table do
        quote do
          require Ecto.Schema
          Ecto.Schema.unquote(embed)(unquote_splicing(args))
        end
      else
        quote do
          require Ecto.Schema
          Ecto.Schema.unquote(embeds[embed])(unquote_splicing(args))
        end
      end

    {ast, module}
  end

  def handle_node({:belongs_to, meta, [name, queryable]}, module) do
    handle_node({:belongs_to, meta, [name, queryable, []]}, module)
  end

  def handle_node({:belongs_to, _meta, args}, module) do
    table = Module.get_attribute(module, :table, false)

    if table do
      Module.put_attribute(module, :belongs_to, List.to_tuple(args))

      ast =
        quote do
          require Ecto.Schema
          Ecto.Schema.belongs_to(unquote_splicing(args))
        end

      {ast, module}
    else
      raise "#{inspect(module)} has defined a belongs_to association, but is an embedded_schema."
    end
  end

  def handle_node(node, module), do: {node, module}

  @doc false
  defp sanitize(opts) do
    opts
    |> Keyword.delete(:required)
    |> Keyword.delete(:alias)
  end

  defp register_attributes(module) do
    Module.register_attribute(module, :fields, accumulate: true)
    Module.register_attribute(module, :required, accumulate: true)
    Module.register_attribute(module, :has_one, accumulate: true)
    Module.register_attribute(module, :required_has_one, accumulate: true)
    Module.register_attribute(module, :many_to_many, accumulate: true)
    Module.register_attribute(module, :required_many_to_many, accumulate: true)
    Module.register_attribute(module, :has_many, accumulate: true)
    Module.register_attribute(module, :required_has_many, accumulate: true)
    Module.register_attribute(module, :aliases, accumulate: true)
    Module.register_attribute(module, :belongs_to, accumulate: true)
    Module.register_attribute(module, :timestamps, [])
  end

  @doc false
  def names(list) do
    Enum.map(list, fn
      {name, _} -> name
      {name, _, _} -> name
    end)
  end

  @doc false
  def accumulated_attribute(module, name) do
    case Module.get_attribute(module, name, []) do
      tuple when is_tuple(tuple) ->
        [tuple]

      nil ->
        []

      list when is_list(list) ->
        list

      other ->
        raise "Unexpected: #{inspect(other)}"
    end
  end

  defp cast_has_ast(table, required_embed_names, all_embed_names) do
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
  end

  defp assoc_names(names) do
    Enum.map(names, &:"#{&1}_id")
  end

  defp gen_funcs(module) do
    fields = accumulated_attribute(module, :fields)
    required = accumulated_attribute(module, :required)
    has_one = accumulated_attribute(module, :has_one)
    belongs_to = accumulated_attribute(module, :belongs_to)

    required_has_one = accumulated_attribute(module, :required_has_one)

    many_to_many = accumulated_attribute(module, :many_to_many)
    required_many_to_many = accumulated_attribute(module, :required_many_to_many)
    many_to_many_names = names(many_to_many) ++ names(required_many_to_many)
    required_many_to_many_names = names(required_many_to_many)

    has_many = accumulated_attribute(module, :has_many)
    required_has_many = accumulated_attribute(module, :required_has_many)
    aliases = accumulated_attribute(module, :aliases)

    table = Module.get_attribute(module, :table, false)

    required_names = names(required)
    names = names(fields) ++ names(required) ++ (belongs_to |> names |> assoc_names)

    required_has_one_names = names(required_has_one)
    has_one_names = names(has_one) ++ names(required_has_one)

    belongs_to_names = names(belongs_to)

    required_has_many_names = names(required_has_many)
    has_many_names = names(has_many) ++ names(required_has_many)

    # timestamps = Module.get_attribute(module, :timestamps, nil)

    required_embed_names = required_has_one_names ++ required_has_many_names ++ required_many_to_many_names

    all_embed_names = has_one_names ++ has_many_names ++ belongs_to_names ++ many_to_many_names

    quote do
      @type nullable(t) :: t | nil

      @typedoc """
      Anything accepted as the first argument to `Ecto.Changeset.cast/4`
      """
      @type data ::
              Ecto.Schema.t()
              | Ecto.Changeset.t()
              | {Ecto.Changeset.data(), Ecto.Changeset.types()}

      @typedoc """
      Anything accepted as the second argument to `Ecto.Changeset.cast/4`
      """
      @type params :: map()

      @typedoc "A string describing why a particular field is invalid"
      @type error_message :: String.t()

      @typedoc """
      The name of a field, which may map to:
      - A scalar value (string, integer, etc.)
      - A `has_one` association
      - A `has_many` association
      """
      @type field :: atom

      @typedoc """
      Maps from a field name to one of 3 cases:

      - A list of error messages if the field is invalid
      - An error map for a `has_one` association
      - A list of error maps for a `has_many` association
      """
      @type errors :: %{field => [error_message] | errors | [errors]}

      use Schemata.Renderable,
        assocs: unquote(all_embed_names)

      @doc """
      Accepts data and params, and returns either:
      - an instance of this type with the params applied
      - an `t:errors/0` map, which maps from field names to error messages, or maps 

      When called, aliases are expanded. If params contains multiple aliased
      fields which can resolve to the same field, the one which wins is
      undefined.

      This function:
      1. Casts the data
      1. Validates that all required fields are present
      1. Casts all embeds/associations
      1. Passes the resulting changeset to an optional `changeset/1` function
      where a developer may add any additional validations or constraints.
      """
      @spec changeset(data, params) :: Ecto.Changeset.t()
      def changeset(data, params) do
        import Ecto.Changeset

        params = Schemata.Params.resolve_aliases(params, unquote(aliases))

        cs =
          data
          |> cast(params, unquote(names))
          |> validate_required(unquote(required_names))

        cs = unquote(cast_has_ast(table, required_embed_names, all_embed_names))

        __MODULE__.changeset(cs)
      end

      @doc """
      An optional function where a dev can add any arbitrary validations or
      constraints.

      ### Example

      ```elixir
      import Ecto.Changeset

      def changeset(%Ecto.Changeset{} = changeset) do
        changeset
        |> validate_length(:name, max: 100)
        |> unique_constraint(:email)
      end
      ```
      """
      @spec changeset(Ecto.Changeset.t()) :: Ecto.Changeset.t()
      def changeset(%Ecto.Changeset{} = changeset), do: changeset
      defoverridable changeset: 1

      unless Module.defines_type?(__MODULE__, {:t, 0}) do
        @typedoc """
        An instance of #{inspect(__MODULE__)}
        """
        @type t :: %__MODULE__{}
      end

      @doc """
      Returns a freshly initialized struct of type t().
      """
      @spec new() :: t()
      def new, do: %__MODULE__{}
      defoverridable new: 0

      @doc """
      Takes a changeset and returns the resulting `t:errors/0`.
      If the changeset is valid, it returns an empty map.
      """
      @spec errors(Ecto.Changeset.t()) :: errors
      def errors(%Ecto.Changeset{valid?: false} = changeset) do
        Schemata.errs(changeset)
      end

      def errors(%Ecto.Changeset{}), do: %{}

      @spec from_map(map) :: {:ok, t} | {:error, errors}
      def from_map(map) do
        cs = __MODULE__.changeset(__MODULE__.new(), map)

        if cs.valid? do
          {:ok, Ecto.Changeset.apply_changes(cs)}
        else
          {:error, errors(cs)}
        end
      end
    end
  end

  defmacro defschema(table, do: block) do
    register_attributes(__CALLER__.module)

    Module.put_attribute(__CALLER__.module, :table, table)

    {block, _} = Macro.prewalk(block, __CALLER__.module, &handle_node/2)

    quote do
      Ecto.Schema.schema unquote(table) do
        unquote(block)
      end

      unquote(gen_funcs(__CALLER__.module))
    end
  end

  defmacro defschema(do: block) do
    register_attributes(__CALLER__.module)
    {block, _} = Macro.prewalk(block, __CALLER__.module, &handle_node/2)

    quote do
      Ecto.Schema.embedded_schema do
        unquote(block)
      end

      unquote(gen_funcs(__CALLER__.module))
    end
  end

  def errs(%Ecto.Changeset{valid?: false} = cs) do
    Ecto.Changeset.traverse_errors(cs, &traverse/1)
  end

  defp traverse({msg, opts}) do
    Enum.reduce(opts, msg, &reducer/2)
  end

  defp reducer({k, v}, acc) when not is_tuple(k) and not is_tuple(v) do
    String.replace(acc, "%{#{k}}", to_string(v))
  end

  defp reducer(_kv, acc), do: acc
end
