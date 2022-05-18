defmodule AttributesTest do
  use ExUnit.Case, async: true

  describe "take_attrs" do
    test "handles flat attributes" do
      assert Attributes.get([id: 1], [:id]) == %{id: 1}
    end

    test "does not add attribute if missing" do
      attrs = Attributes.get([obj: %{}], [[:obj, :id]])
      assert attrs == %{}

      attrs = Attributes.get([], [[:obj, :id]])
      assert attrs == %{}
    end

    test "does not add attribute if object is nil" do
      assert Attributes.get([obj: nil], [[:obj, :id]]) == %{}
    end
  end

  describe "maybe_add_result" do
    test "when :result is given, adds result to the list" do
      attrs = Attributes.get([], [:result], {:ok, "include me"})
      assert attrs == %{result: "{:ok, \"include me\"}"}

      attrs = Attributes.get([id: 10], [:result, :id], {:ok, "include me"})
      assert attrs == %{result: "{:ok, \"include me\"}", id: 10}
    end

    test "when :result is missing, does not add result to the list" do
      attrs = Attributes.get([], [], {:ok, "include me"})
      assert attrs == %{}

      attrs = Attributes.get([name: "blah"], [:name], {:ok, "include me"})

      assert attrs == %{name: "blah"}
    end
  end

  describe "remove_underscores" do
    test "removes underscores from keys" do
      assert Attributes.get([_id: 1], [:_id]) == %{id: 1}

      assert Attributes.get([_id: 1, _name: "asd"], [:_id, :_name]) ==
               %{
                 id: 1,
                 name: "asd"
               }
    end

    test "doesn't modify keys without underscores" do
      assert Attributes.get([_id: 1, name: "asd"], [:_id, :name]) ==
               %{
                 id: 1,
                 name: "asd"
               }
    end
  end
end
