use Schemata

defnamespace MyApp.Retail do
  defschema Thing, table: "my_table" do
    field(:first_name, :string, required: true)

    query_field(:first_name)
  end

  defschema Employee do
    field(:first_name, :string, required: true)
    field(:last_name, :string, required: true)

    # `namespaced/1` takes a module name and prepends the namespace to it.
    # Even though this is an embedded schema, we use `has_many` and `has_one`,
    # not `embeds_many` or `embeds_one`
    has_one(:address, namespaced(Address), required: true)
  end

  defschema Address do
    field(:address_line_1, :string, required: true, alias: :line_1)
    field(:address_line_2, :string, alias: :line_2)
    field(:city, :string, required: true)
    field(:state, :string, required: true, alias: :region)
    field(:zip_code, :string, required: true)
  end

  defschema Location do
    has_one(:address, namespaced(Address), required: true)
    has_one(:manager, namespaced(Employee), required: true)
    has_many(:employees, namespaced(Employee), required: true)

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
        is_nil(manager) or is_nil(employees) ->
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
