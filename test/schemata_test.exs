defmodule Testing.Embed do
  use Schemata

  defschema do
    field(:first_name, :string, required: true, alias: :firstName)
    field(:last_name, :string)
  end
end

defmodule Testing.TestSchema do
  use Schemata
  alias Testing.Embed

  defschema do
    field(:name, :string, required: true)
    field(:optional, :integer)
    field(:other, :integer, default: 0)

    has_one(:required_embed, Embed, required: true, alias: :req_embed)
    has_one(:optional_embed, Embed)
    has_many(:required_embeds, Embed, required: true, alias: :req_embeds)
    has_many(:optional_embeds, Embed, alias: :op_embeds)
  end

  def changeset(%Ecto.Changeset{} = cs) do
    validate_number(cs, :optional, greater_than_or_equal_to: 10)
  end
end

defmodule TestSchema.Test do
  use ExUnit.Case

  @embed %{first_name: "name2", optional: "abc"}

  use Schemata.ChangesetTest,
    module: Testing.TestSchema,
    valid_params: %{
      name: "name",
      required_embed: @embed,
      required_embeds: [@embed],
      optional_embeds: [@embed],
      optional_embed: @embed,
      optional_field: 10
    }

  alias Testing.Embed

  alias Schemata.Params

  valid_params!()

  required_fields([:name, :required_embed, :required_embeds])
  default_values(other: 0)
  optional_fields([:optional_embeds, :optional_embed, :optional_field, :other])

  describe "new/0" do
    test "returns a struct" do
      %@test_module{} = @test_module.new()
    end
  end

  describe "from_map/1" do
    @valid_string_params Schemata.Params.atom_keys_to_string(@valid_params)
    @invalid_params %{}

    test "valid_params are valid" do
      assert %{valid?: true} = @test_module.changeset(@test_module.new, @valid_params)
    end

    test "invalid_params are invalid" do
      assert %{valid?: false} = @test_module.changeset(@test_module.new, @invalid_params)
    end

    test "returns an ok tuple if valid" do
      {:ok, _} = @test_module.from_map(@valid_params)
    end

    test "returns a struct if valid" do
      {_, %@test_module{}} = @test_module.from_map(@valid_params)
    end

    test "returns an error tuple if invalid" do
      {:error, _} = @test_module.from_map(@invalid_params)
    end

    test "Returns an error map if invalid" do
      {_, %{name: ["can't be blank"]}} = @test_module.from_map(@invalid_params)
    end

    test "valid_string_params are valid" do
      assert %{valid?: true} = @test_module.changeset(@test_module.new, @valid_string_params)
    end

    test "returns an ok tuple if valid (string keys)" do
      {:ok, _} = @test_module.from_map(@valid_string_params)
    end

    test "returns a struct if valid (string keys)" do
      {_, %@test_module{}} = @test_module.from_map(@valid_string_params)
    end

    test "is invalid if required field is missing" do
      assert {:error, %{first_name: ["can't be blank"]}} =
               @embed
               |> Map.delete(:first_name)
               |> Embed.from_map()
    end

    test "allows aliases in params" do
      assert {:ok, %Embed{}} =
               @embed
               |> Params.rename_key(:first_name, :firstName)
               |> Embed.from_map()
    end

    test "does not maintain the alias when converting the struct to a map" do
      {:ok, %Embed{} = embed} =
        @embed
        |> Params.rename_key(:first_name, :firstName)
        |> Embed.from_map()

      assert %{first_name: _} = Embed.to_map(embed)
    end

    test "is still valid if optional params are ommitted" do
      assert {:ok, %Embed{}} =
               @embed
               |> Map.delete(:optional)
               |> Embed.from_map()
    end

    test "is invalid if a required has_one is ommitted" do
      assert {:error, %{required_embed: ["can't be blank"]}} =
               @valid_params
               |> Map.delete(:required_embed)
               |> @test_module.from_map
    end

    test "is invalid if a required has_many is ommitted" do
      assert {:error, %{required_embeds: ["can't be blank"]}} =
               @valid_params
               |> Map.delete(:required_embeds)
               |> @test_module.from_map
    end

    test "is valid if an optional has_one is ommitted" do
      assert {:ok, %@test_module{}} =
               @valid_params
               |> Map.delete(:optional_embed)
               |> @test_module.from_map
    end

    test "is valid if an optional has_many is ommitted" do
      assert {:ok, %@test_module{}} =
               @valid_params
               |> Map.delete(:optional_embeds)
               |> @test_module.from_map
    end

    test "is valid if an optional has_many is aliased" do
      assert {:ok, %@test_module{}} =
               @valid_params
               |> Params.rename_key(:optional_embeds, :op_embeds)
               |> @test_module.from_map
    end

    test "is invalid if an optional has_many is nil" do
      assert {:error, %{optional_embeds: ["is invalid"]}} =
               @valid_params
               |> Map.put(:optional_embeds, nil)
               |> @test_module.from_map
    end

    test "is invalid if an optional has_many is aliased and nil" do
      assert {:error, %{optional_embeds: ["is invalid"]}} =
               @valid_params
               |> Map.put(:optional_embeds, nil)
               |> Params.rename_key(:optional_embeds, :op_embeds)
               |> @test_module.from_map
    end

    test "calls an optional changeset/1 function" do
      assert {:error, %{optional: ["must be greater than or equal to 10"]}} =
               @valid_params
               |> Map.put(:optional, 9)
               |> @test_module.from_map
    end
  end
end
