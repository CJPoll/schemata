use Schemata

defschema TestSchema do
  field :name, :string, required: true
end

defmodule TestSchema.Test do
  use ExUnit.Case
  @test_module TestSchema

  describe "new/0" do
    test "returns a struct" do
      %@test_module{} = @test_module.new()
    end
  end

  describe "from_map/1" do
    @valid_params %{name: "name"}
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
  end
end
