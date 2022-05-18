defmodule OpenTelemetryDecorator do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.filter(&(&1 =~ ~R{<!\-\-\ INCLUDE\ \-\->}))
             |> Enum.join("\n")
             # compensate for anchor id differences between ExDoc and GitHub
             |> (&Regex.replace(~R{\(\#\K(?=[a-z][a-z0-9-]+\))}, &1, "module-")).()

  use Decorator.Define, with_span: 0, with_span: 1

  @doc """
  Decorate a function to add an OpenTelemetry span to the current trace.

  You can provide span attributes by specifying a list of variable names as atoms.
  This list can include:

  - any variables (in the top level closure) available when the function exits,
  - the result of the function by including the atom `:result`,

  ```elixir
  defmodule MyApp.Worker do
    use OpenTelemetryDecorator

    @decorate with_span("my_app.worker.do_work", include: [:arg1, [:arg2, :count], :total, :result])
    def do_work(arg1, arg2) do
      total = arg1.count + arg2.count
      {:ok, total}
    end
  end
  ```
  """
  def with_span(opts \\ [], body, context) do
    include = Keyword.get(opts, :include, [])
    Validator.validate_args(include)

    span_name = "#{module_name(context.module)}.#{context.name}/#{context.arity}"

    quote location: :keep do
      require OpenTelemetry.Span
      require OpenTelemetry.Tracer

      OpenTelemetry.Tracer.with_span unquote(span_name) do
        span_ctx = OpenTelemetry.Tracer.current_span_ctx()

        case unquote(body) do
          {:error, reason} = error ->
            included_attrs = Attributes.get(Kernel.binding(), unquote(include))
            Map.put(included_attrs, :"error.reason", inspect(reason))
            OpenTelemetry.Span.set_attributes(span_ctx, included_attrs)
            OpenTelemetry.Span.set_status(span_ctx, OpenTelemetry.status(:error, ""))
            error

          _ = result ->
            included_attrs = Attributes.get(Kernel.binding(), unquote(include), result)
            OpenTelemetry.Span.set_attributes(span_ctx, included_attrs)
            result
        end
      end
    end
  rescue
    e in ArgumentError ->
      target = "#{inspect(context.module)}.#{context.name}/#{context.arity} @decorate telemetry"
      reraise %ArgumentError{message: "#{target} #{e.message}"}, __STACKTRACE__
  end

  @spec module_name(atom() | String.t()) :: String.t()
  defp module_name("Elixir." <> module), do: module

  defp module_name(module) when is_binary(module), do: module

  defp module_name(module), do: module |> to_string() |> module_name()
end
