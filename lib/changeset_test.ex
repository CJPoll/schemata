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

  defmacro required_fields(fields) when is_list(fields) do
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

  defmacro default_values(keyword) do
    for {field, value} <- keyword do
      quote do
        unquote(__MODULE__).default_value(unquote(field), unquote(value))
      end
    end
  end

  defmacro default_value(field, default) do
    quote do
      test "#{unquote(field)} defaults to #{inspect(unquote(default))}" do
        params = @valid_params |> Schemata.Params.delete_key(unquote(field))
        changeset = @test_module.changeset(@test_module.new(), params)

        if changeset.valid? do
          assert %@test_module{unquote(field) => unquote(default)} =
                   Ecto.Changeset.apply_changes(changeset)
        else
          assert %{valid?: true} = changeset
        end
      end
    end
  end

  defmacro optional_fields(fields) do
    for field <- fields do
      quote do
        unquote(__MODULE__).optional_field(unquote(field))
      end
    end
  end

  defmacro optional_field(field) do
    quote do
      test "#{unquote(field)} is optional" do
        params = @valid_params |> Schemata.Params.delete_key(unquote(field))
        changeset = @test_module.changeset(@test_module.new(), params)

        if changeset.valid? do
          assert changeset.valid?
        else
          assert %{valid?: true} = changeset
        end
      end
    end
  end
end
