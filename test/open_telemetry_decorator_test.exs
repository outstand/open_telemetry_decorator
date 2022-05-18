defmodule OpenTelemetryDecoratorTest do
  use ExUnit.Case, async: true
  doctest OpenTelemetryDecorator

  require OpenTelemetry.Tracer
  require OpenTelemetry.Span

  require Record

  # Make span methods available
  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry/include/otel_span.hrl") do
    Record.defrecord(name, spec)
  end

  setup do
    ExUnit.CaptureLog.capture_log(fn ->
      :otel_simple_processor.set_exporter(:otel_exporter_pid, self())
    end)

    :ok
  end

  defmodule Example do
    use OpenTelemetryDecorator

    @decorate with_span(include: [:id, :result])
    def step(id), do: {:ok, id}

    @decorate with_span(include: [:count, :result])
    def workflow(count), do: Enum.map(1..count, fn id -> step(id) end)

    @decorate with_span(include: [:up_to])
    def numbers(up_to), do: [1..up_to]

    @decorate with_span(include: [:id, [:user, :name], :error, :_even, :result])
    def find(id) do
      _even = rem(id, 2) == 0
      user = %{id: id, name: "my user"}

      case id do
        1 ->
          {:ok, user}

        error ->
          {:error, error}
      end
    end

    @decorate with_span()
    def no_include(opts), do: {:ok, opts}
  end

  describe "with_span" do
    test "does not modify inputs or function result" do
      assert Example.step(1) == {:ok, 1}
    end

    test "automatically links spans" do
      Example.workflow(2)

      assert_receive {:span,
                      span(
                        name: "OpenTelemetryDecoratorTest.Example.workflow/1",
                        trace_id: parent_trace_id,
                        attributes: attributes
                      )}
      assert %{
        result: "[ok: 1, ok: 2]",
        count: 2
      } = :otel_attributes.map(attributes)

      assert_receive {:span,
                      span(
                        name: "OpenTelemetryDecoratorTest.Example.step/1",
                        trace_id: ^parent_trace_id,
                        attributes: attributes
                      )}
      assert %{
        result: "{:ok, 1}",
        id: 1
      } = :otel_attributes.map(attributes)

      assert_receive {:span,
                      span(
                        name: "OpenTelemetryDecoratorTest.Example.step/1",
                        trace_id: ^parent_trace_id,
                        attributes: attributes
                      )}
      assert %{
        result: "{:ok, 2}",
        id: 2
      } = :otel_attributes.map(attributes)
    end

    test "handles simple attributes" do
      Example.find(1)
      assert_receive {:span, span(name: "OpenTelemetryDecoratorTest.Example.find/1", attributes: attributes)}
      assert %{
        id: 1
      } = :otel_attributes.map(attributes)
    end

    test "handles handles underscored attributes" do
      Example.find(2)
      assert_receive {:span, span(name: "OpenTelemetryDecoratorTest.Example.find/1", attributes: attributes)}
      assert %{
        even: "true"
      } = :otel_attributes.map(attributes)
    end

    test "converts atoms to strings" do
      Example.step(:two)
      assert_receive {:span, span(name: "OpenTelemetryDecoratorTest.Example.step/1", attributes: attributes)}
      assert %{
        id: "two"
      } = :otel_attributes.map(attributes)
    end

    test "does not include result unless asked for" do
      Example.numbers(1000)
      assert_receive {:span, span(name: "OpenTelemetryDecoratorTest.Example.numbers/1", attributes: attributes)}
      assert Map.has_key?(:otel_attributes.map(attributes), :result) == false
    end

    test "does not include variables not in scope when the function exists" do
      Example.find(098)
      assert_receive {:span, span(name: "OpenTelemetryDecoratorTest.Example.find/1", attributes: attributes)}
      assert Map.has_key?(:otel_attributes.map(attributes), :error) == false
    end

    test "does not include anything unless specified" do
      Example.no_include(include_me: "nope")
      assert_receive {:span, span(name: "OpenTelemetryDecoratorTest.Example.no_include/1", attributes: attributes)}
      assert %{} == :otel_attributes.map(attributes)
    end
  end
end
