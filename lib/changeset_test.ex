defmodule Schemata.ChangesetTest do
  defmacro __using__(opts) do
    valid_params = Keyword.fetch!(opts, :valid_params)
    changeset_module = Keyword.fetch!(opts, :module)

    quote do
      import unquote(__MODULE__)

      @valid_params unquote(valid_params)
      @test_module unquote(changeset_module)
    end
  end

  defmacro valid_params! do
    quote do
      test "has valid_params defined" do
        changeset = @test_module.changeset(@test_module.new(), @valid_params)
        assert %{valid?: true} = changeset
      end
    end
  end

  defmacro required_fields(fields) do
    for field <- fields do
      quote do
        unquote(__MODULE__).required_field(unquote(field))
      end
    end
  end

  defmacro required_field(field) do
    quote do
      test "#{unquote(field)} is required" do
        params = @valid_params |> Schemata.Params.delete_key(unquote(field))
        changeset = @test_module.changeset(@test_module.new(), params)

        if changeset.valid? do
          assert %{valid?: false} = changeset
        else
          refute changeset.valid?
        end
      end
    end
  end
end
