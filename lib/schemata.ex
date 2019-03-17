defmodule Mac do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro defprint({name, _, args}, do: block) do
    quote do
      def unquote(name)(unquote_splicing(args)) do
        args =
          Enum.map(unquote(args), fn ast ->
            inspect(Macro.escape(ast))
          end)

        IO.inspect(
          "Calling #{inspect(__MODULE__)}.#{inspect(unquote(name))}/#{unquote(length(args))} with args: #{
            args
          }"
        )

        func = fn ->
          unquote(block)
        end

        ret = func.()

        IO.inspect(
          "#{inspect(__MODULE__)}.#{inspect(unquote(name))}/#{unquote(length(args))} returned: #{
            inspect(ret)
          }"
        )

        ret
      end
    end
  end
end

defmodule Schemata.Compile do
  @moduledoc false
  use Mac
  # alias Schemata.Types

  def names(list) do
    Enum.map(list, fn
      [name, _] -> name
      [name, _, _] -> name
    end)
  end

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

  def do_compile(module, initial) do
    fields = accumulated_attribute(module, :fields)
    required = accumulated_attribute(module, :required)
    has_one = accumulated_attribute(module, :has_one)

    required_has_one = accumulated_attribute(module, :required_has_one)

    has_many = accumulated_attribute(module, :has_many)
    required_has_many = accumulated_attribute(module, :required_has_many)
    aliases = accumulated_attribute(module, :aliases)
    belongs_to = accumulated_attribute(module, :belongs_to)

    table = Module.get_attribute(module, :table, false)

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
            # typespec_name = Macro.var(name, __MODULE__)
            # typespec_type = Types.type(type)

            quote do
              Ecto.Schema.field(unquote(name), unquote(type))
            end

          [name, type, opts] ->
            # typespec_name = Macro.var(name, __MODULE__)
            # typespec_type = Types.type(type)

            quote do
              Ecto.Schema.field(unquote(name), unquote(type), unquote(opts))
            end

          _ ->
            []
        end) ++
        Enum.map(has_one ++ required_has_one, fn
          [name, type] ->
            # typespec_name = Macro.var(name, __MODULE__)
            # typespec_type = Types.type(type)

            cond do
              is_nil(table) and type in required_has_one ->
                quote do
                  Ecto.Schema.embeds_one(unquote(name), unquote(type))
                end

              type in required_has_one ->
                quote do
                  Ecto.Schema.has_one(unquote(name), unquote(type))
                end

              is_nil(table) ->
                quote do
                  Ecto.Schema.embeds_one(unquote(name), unquote(type))
                end

              true ->
                quote do
                  Ecto.Schema.has_one(unquote(name), unquote(type))
                end
            end

          [name, type, opts] ->
            opts = Keyword.delete(opts, :required)
            # typespec_name = Macro.var(name, __MODULE__)
            # typespec_type = Types.type(type)

            cond do
              is_nil(table) and type in required_has_one ->
                quote do
                  Ecto.Schema.embeds_one(unquote(name), unquote(type), unquote(opts))
                end

              type in required_has_one ->
                quote do
                  Ecto.Schema.has_one(unquote(name), unquote(type), unquote(opts))
                end

              is_nil(table) ->
                quote do
                  Ecto.Schema.embeds_one(unquote(name), unquote(type), unquote(opts))
                end

              true ->
                quote do
                  Ecto.Schema.has_one(unquote(name), unquote(type), unquote(opts))
                end
            end

          _ ->
            []
        end) ++
        Enum.map(has_many ++ required_has_many, fn
          [name, type] ->
            # typespec_name = Macro.var(name, __MODULE__)
            # typespec_type = Types.type(type)

            cond do
              is_nil(table) and type in required_has_many ->
                quote do
                  Ecto.Schema.embeds_many(unquote(name), unquote(type))
                end

              type in required_has_many ->
                quote do
                  Ecto.Schema.has_many(unquote(name), unquote(type))
                end

              is_nil(table) ->
                quote do
                  Ecto.Schema.embeds_many(unquote(name), unquote(type))
                end

              true ->
                quote do
                  Ecto.Schema.has_many(unquote(name), unquote(type))
                end
            end

          [name, type, opts] ->
            opts = Keyword.delete(opts, :required)
            # typespec_name = Macro.var(name, __MODULE__)
            # typespec_type = Types.type(type)

            cond do
              is_nil(table) and type in required_has_many ->
                quote do
                  Ecto.Schema.embeds_many(unquote(name), unquote(type), unquote(opts))
                end

              type in required_has_many ->
                quote do
                  Ecto.Schema.has_many(unquote(name), unquote(type), unquote(opts))
                end

              is_nil(table) ->
                quote do
                  Ecto.Schema.embeds_many(unquote(name), unquote(type), unquote(opts))
                end

              true ->
                quote do
                  Ecto.Schema.has_many(unquote(name), unquote(type), unquote(opts))
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
      @type nullable(t) :: t | nil

      unquote(schema)

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
        embeds: unquote(all_embed_names)

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
      @spec changeset(data, params) :: {:ok, t} | {:error, errors}
      def changeset(data, params) do
        import Ecto.Changeset

        params = Schemata.Params.resolve_aliases(params, unquote(aliases))

        cs =
          data
          |> cast(params, unquote(names))
          |> validate_required(unquote(required_names))

        cs = unquote(cast_has_ast)

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
      @spec changeset(Ecto.Changeset.t()) :: {:ok, t} | {:error, errors}
      def changeset(%Ecto.Changeset{} = changeset), do: changeset
      defoverridable changeset: 1

      unquote(initial)

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
end

defmodule Schemata do
  @moduledoc """
  Schemata is designed to reduce the amount of boilerplate required when
  creating Ecto schemas.

  It does this in a few ways:

  1. It generates a `new/0` constructor function for your schema
  1. It generates a `changeset/2` function which handles casts (including embeds
  and associations), and validates required fields/embeds/associations are
  present.
  1. It allows you to define a `changeset/1` function, which takes a
  changeset as an argument. This allows you to use all the ecto validation or
  constraint functions.
  1. It allows you to define aliases for fields, for when incoming params might
  have names that don't necessarily make sense for your application
  (e.g. camel-cased names instead of snake cased)
  1. Lightly extends the Ecto.Schema DSL with `:required` and `:alias` options
  1. Lightly wraps the embedded schema and table-backed schema DSLs and unifies them
  1. For embedded schemas, allows you to easily group multiple schemas together
  under a namespace.

  Embedded Schema Example:

  ```elixir
  use Schemata

  defnamespace MyApp.Retail do
    defschema Address do
      field :address_line_1, :string, required: true, alias: :line_1
      field :address_line_2, :string, alias: :line_2
      field :city, :string, required: true
      field :state, :string, required: true, alias: :region
      field :zip_code, :string, required: true
    end

    defschema Employee do
      field :first_name, :string, required: true
      field :last_name, :string, required: true

      # `namespaced/1` takes a module name and prepends the namespace to it.
      # Even though this is an embedded schema, we use `has_many` and `has_one`,
      # not `embeds_many` or `embeds_one`
      has_one :address, namespaced(Address), required: true
    end

    defschema Location do
      has_one :address, namespaced(Address), required: true
      has_one :manager, namespaced(Employee), required: true
      has_many :employees, namespaced(Employee), required: true

      def changeset(cs) do
        # Let's assume there's a business rule that the manager _must_ be
        # present in the :employees field.

        # If we have multiple business rules to check, this can be turned into
        # a pipeline.
        validate_manager_in_employees(cs)
      end

      defp validate_manager_in_employees(cs) do
        {_, manager} = fetch_field(cs, :manager)
        {_, employees} = fetch_field(cs, :employees)

        cond do
          is_nil(manager) or is_nil(employees)->
            # Since :manager and employees are required, the generated
            # validate_required has already put this error into the changeset
            cs

          employees == [] ->
            # Since the :employees relation requires at least one employee to be
            # present, the generated validate_required has already put this error
            # into the changeset
            cs

          manager in employees ->
            # This business rule has been satisfied
            cs

          true ->
            # The business rule has been violated
            add_error(cs, :manager, "must be present in employees field 😱")
        end
      end
    end
  end
  ```

  In this example, You could do the following:

  ```elixir
  iex(1)> alias MyApp.Retail.{Address, Employee, Location}
  [MyApp.Retail.Address, MyApp.Retail.Employee, MyApp.Retail.Location]

  # new/0 returns an uninitialized and un-validated struct
  iex(2)> Location.new()
  %MyApp.Retail.Location{address: nil, employees: [], manager: nil}

  iex(3)> Location.from_map(%{
    address: %{
      address_line_1: "123 Fake Street",
      city: "Draper", state: "UT", zip_code: "84062"
    },
    employees: [
      %{
        first_name: "Joe", last_name: "Dirt", address:
        %{
          address_line_1: "1234 Unreal Street",
          city: "Salt Lake City", state: "UT", zip_code: "84062"
        }
      },
      %{
        first_name: "Jane", last_name: "Doe", address:
        %{
          address_line_1: "12345 Fake Circle",
          city: "Salt Lake City", state: "UT", zip_code: "84062"
        }
      }
    ],
    manager: %{
        first_name: "Jane", last_name: "Doe", address:
        %{
          address_line_1: "12345 Fake Circle",
          city: "Salt Lake City", state: "UT", zip_code: "84062"
        }
      }
  })
  {:ok,
    %MyApp.Retail.Location{
      address: %MyApp.Retail.Address{
        address_line_1: "123 Fake Street",
        address_line_2: nil,
        city: "Draper",
        state: "UT",
        zip_code: "84062"
      },
      employees: [
        %MyApp.Retail.Employee{
          address: %MyApp.Retail.Address{
            address_line_1: "1234 Unreal Street",
            address_line_2: nil,
            city: "Salt Lake City",
            state: "UT",
            zip_code: "84062"
          },
          first_name: "Joe",
          last_name: "Dirt"
        },
        %MyApp.Retail.Employee{
          address: %MyApp.Retail.Address{
            address_line_1: "12345 Fake Circle",
            address_line_2: nil,
            city: "Salt Lake City",
            state: "UT",
            zip_code: "84062"
          },
          first_name: "Jane",
          last_name: "Doe"
        }
      ],
      manager: %MyApp.Retail.Employee{
        address: %MyApp.Retail.Address{
          address_line_1: "12345 Fake Circle",
          address_line_2: nil,
          city: "Salt Lake City",
          state: "UT",
          zip_code: "84062"
        },
        first_name: "Jane",
        last_name: "Doe"
      }
    }}

  """
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc """
  When building out embedded schemas, it's often convenient to group them
  together in a single file. When doing this, typing out fully qualified module
  names gets cumbersome. `defnamespace` allows us to skip some of that
  boilerplate.

  Example:

  ```elixir
  use Schemata

  defnamespace MyApp.Accounts do
    defschema Credential do
      field :email, :string, required: true
      field :password, :string, virtual: true
      field :password_confirmation, :string, virtual: true
      field :hashed_password, :string, virtual: true
      field :active?, :boolean, required: true

      timestamps()
    end

    defschema User do
      field :display_name, :string
      has_many :credentials, namespaced(Credential)
    end
  end
  ```

  In this example, the fully qualified modulenames are
  `MyApp.Accounts.Credential` and `MyApp.Accounts.User`. Because of some macro
  shenanigans I'm trying to work out regarding `alias` in these schemas, the
  `namespaced/1` expands a given module name to it's fully qualified name.
  """
  defmacro defnamespace({:__aliases__, _, left}, do: block) do
    Macro.prewalk(block, fn
      {:defschema, meta, [{:__aliases__, meta, right}, [do: block]]} ->
        {:defschema, meta, [{:__aliases__, meta, Enum.concat(left, right)}, [do: block]]}

      {:defschema, meta, [{:__aliases__, meta, right}, [table: table], [do: block]]} ->
        {:defschema, meta,
         [{:__aliases__, meta, Enum.concat(left, right)}, [table: table], [do: block]]}

      {:defmodule, meta, [{:__aliases__, meta, right}, [do: block]]} ->
        {:defschema, meta, [{:__aliases__, meta, Enum.concat(left, right)}, [do: block]]}

      {:ns, _, [{:__aliases__, meta, right}]} ->
        {:__aliases__, meta, Enum.concat(left, right)}

      {:namespaced, _, [{:__aliases__, meta, right}]} ->
        {:__aliases__, meta, Enum.concat(left, right)}

      other ->
        other
    end)
  end

  @doc false
  defmacro deffields(table, do: block) do
    Module.put_attribute(__CALLER__.module, :table, table)

    quote do
      unquote(__MODULE__).deffields(do: unquote(block))
    end
  end

  @doc false
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

  @doc false
  def handle_node({:field, _meta, [name, type, opts]}, module) do
    required = Keyword.get(opts, :required, false)

    if alias = Keyword.get(opts, :alias, nil) do
      unless is_atom(alias) do
        raise "alias #{inspect(alias)} for field #{inspect(name)} of #{inspect(module)} must be an atom, not a string"
      end

      Module.put_attribute(module, :aliases, [alias, name])
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
      Module.put_attribute(module, :aliases, [alias, name])
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
    table = Module.get_attribute(module, :table, false)

    if table do
      Module.put_attribute(module, :belongs_to, args)
      {nil, module}
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

  @doc """
  Defines a schema, and generates several helper functions within it. These
  functions are documented in the generated schema module.

  ### Functions generated:
  - `changeset/2`
  - `errors/1`
  - `from_map/1`
  - `new/0`
  - `to_map/1`

  Additionally, the developer can define a `changeset/1` which gets called by
  the generated `changeset/2` function. This changeset has already had data
  casted, required fields checked, and embeds/associations casted.

  ### Options

  - `:table` - A string with the name of a table to back the schema. Defaults to
  `false`. If false, the schema will be an `embedded_schema`. If set to a string
  value, the schema will be a table-backed schema.

  """
  defmacro defschema(module, opts \\ [], do: block) do
    if table = Keyword.get(opts, :table, false) do
      quote do
        defmodule unquote(module) do
          use Ecto.Schema
          import Ecto.Changeset
          import Schemata.Queries

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

  @doc false
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
end
