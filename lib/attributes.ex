defmodule Attributes do
  @moduledoc false

  def get(bound_variables, reportable_attr_keys, result \\ nil) do
    bound_variables
    |> take_attrs(reportable_attr_keys)
    |> maybe_add_result(reportable_attr_keys, result)
    |> remove_underscores()
    |> convert_atoms_to_strings()
    |> Enum.into(%{})
  end

  defp take_attrs(bound_variables, attr_keys) do
    bound_variables
    |> Keyword.take(attr_keys)
    |> Enum.map(fn {key, value} ->
      value = _inspect(value)
      {key, value}
    end)
  end

  defp maybe_add_result(attrs, attr_keys, result) do
    if Enum.member?(attr_keys, :result) do
      Keyword.put_new(attrs, :result, _inspect(result))
    else
      attrs
    end
  end

  defp remove_underscores(attrs) do
    Enum.map(attrs, fn {key, value} ->
      key =
        key
        |> Atom.to_string()
        |> String.trim_leading("_")
        |> String.to_atom()

      {key, value}
    end)
  end

  defp convert_atoms_to_strings(attrs) do
    Enum.map(attrs, fn {key, value} ->
      if is_atom(value) do
        {key, Atom.to_string(value)}
      else
        {key, value}
      end
    end)
  end

  defp _inspect(term) do
    cond do
      Enumerable.impl_for(term) ->
        inspect(term)
      String.Chars.impl_for(term) ->
        term
      true ->
        inspect(term)
    end
  end
end
