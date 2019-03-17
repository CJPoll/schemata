defmodule Schemata.Queries do
  defmacro query_field(field) when is_atom(field) do
    equality_func_name = :"with_#{field}"
    present_func_name = :"with_present_#{field}"
    missing_func_name = :"missing_#{field}"

    quote do
      def unquote(equality_func_name)(queryable, value) do
        require Ecto.Query
        Ecto.Query.from(queryable, where: [{unquote(field), ^value}])
      end

      def unquote(present_func_name)(queryable) do
        require Ecto.Query
        Ecto.Query.from(q in queryable, where: not is_nil(q.unquote(field)))
      end

      def unquote(missing_func_name)(queryable) do
        require Ecto.Query
        Ecto.Query.from(q in queryable, where: is_nil(q.unquote(field)))
      end
    end
  end

  defmacro query_field(field) do
    raise "Field name #{inspect(field)} must be an atom"
  end

  defmacro query_fields(fields) do
    for field <- fields do
      quote do
        query_field(unquote(field))
      end
    end
  end
end
