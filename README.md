# Schemata

A light wrapper around ecto schemas and changesets to reduce boilerplate.

## Installation

Add `schemata` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:schemata, git: "git@github.com:cjpoll/schemata"}
  ]
end
```

## Usage

```
defmodule MyStruct do
  use Schemata

  defschema do
    field :first_name, :string, required: true
    field :last_name, :string
  end

  def changeset(%Ecto.Changeset{} = cs) do
    validate_length(cs, :first_name, min: 2)
  end
end
```

From this module, you can do:

```elixir
iex(1)> MyStruct.new()
%MyStruct{first_name: nil, id: nil, last_name: nil}

iex(2)> MyStruct.changeset(MyStruct.new(), %{first_name: "Jane", last_name: "Doe"})
#Ecto.Changeset<
  action: nil,
  changes: %{first_name: "Jane", last_name: "Doe"},
  errors: [],
  data: #MyStruct<>,
  valid?: true
>

iex(3)> MyStruct.new() |> MyStruct.changeset(%{first_name: "A", last_name: "Doe"}) |> MyStruct.errors()
%{first_name: ["should be at least 2 character(s)"]}

iex(4)> MyStruct.new() |> MyStruct.changeset(%{last_name: "Doe"}) |> MyStruct.errors()
%{first_name: ["can't be blank"]}

iex(5)> MyStruct.from_map(%{first_name: "Jane"})
{:ok, %MyStruct{first_name: "Jane", id: nil, last_name: nil}}

iex(6)> MyStruct.from_map(%{last_name: "Doe"})
{:error, %{first_name: ["can't be blank"]}}

iex(7)> {:ok, %MyStruct{} = struct} = MyStruct.from_map(%{first_name: "Jane"}); MyStruct.to_map(struct)
%{first_name: "Jane", id: nil, last_name: nil}
```
