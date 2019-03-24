defmodule Parent do
  use Schemata
  defschema do
    field :first_name, :string
    has_one :child, Child, required: true
  end
end

defmodule Child do
  use Schemata
  defschema do
    field :last_name, :string
  end
end
