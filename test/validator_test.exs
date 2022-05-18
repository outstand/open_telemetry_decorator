defmodule ValidatorTest do
  use ExUnit.Case, async: true

  describe "validate_args" do
    test "attr_keys can be empty" do
      Validator.validate_args([])
    end

    test "attrs_keys must be atoms" do
      Validator.validate_args([:variable])

      assert_raise ArgumentError, ~r/^attr_keys/, fn ->
        Validator.validate_args(["variable"])
      end
    end

    test "attrs_keys can contain nested lists of atoms" do
      Validator.validate_args([:variable, [:obj, :key]])
    end
  end
end
