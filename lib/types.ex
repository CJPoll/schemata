defmodule Schemata.Types do
  @moduledoc false

  def type(:string) do
    quote do
      String.t()
    end
  end

  def type(:integer) do
    quote do
      integer()
    end
  end

  def type(:float) do
    quote do
      float()
    end
  end

  def type(:id) do
    quote do
      integer()
    end
  end

  def type(:binary_id) do
    quote do
      binary()
    end
  end

  def type(:boolean) do
    quote do
      boolean()
    end
  end

  def type(:binary) do
    quote do
      binary()
    end
  end

  def type({:array, type}) do
    quote do
      [unquote(type)]
    end
  end

  def type(:map) do
    quote do
      map()
    end
  end

  def type({:map, type}) do
    quote do
      %{String.t() => unquote(type(type))}
    end
  end

  def type(:decimal) do
    quote do
      Decimal
    end
  end

  def type(:date) do
    quote do
      Date
    end
  end

  def type(:time) do
    quote do
      Time
    end
  end

  def type(:naive_datetime) do
    quote do
      NaiveDateTime
    end
  end

  def type(:naive_datetime_usec) do
    quote do
      NaiveDateTime
    end
  end

  def type(:utc_datetime) do
    quote do
      DateTime
    end
  end

  def type(:utc_datetime_usec) do
    quote do
      DateTime
    end
  end

  def type(other) do
    quote do
      unquote(other)
    end
  end
end
