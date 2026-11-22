defmodule PhilomenaMedia.Analyzers.Webm do
  @moduledoc false

  alias PhilomenaMedia.Analyzers.Analyzer
  alias PhilomenaMedia.Analyzers.Result
  alias PhilomenaMedia.Remote

  @behaviour Analyzer

  @spec analyze(Path.t()) :: Result.t()
  def analyze(file) do
    stats = stats(file)

    %Result{
      extension: "webm",
      mime_type: "video/webm",
      animated?: stats.animated?,
      duration: stats.duration,
      dimensions: stats.dimensions
    }
  end

  defp stats(file) do
    case Remote.cmd("mediastat", [file]) do
      {output, 0} ->
        tokens =
          output
          |> String.trim()
          |> String.split(" ", trim: true)

        # Safely parse the 6 expected integers; if output contains error text like "Found...", fall back safely
        parsed = Enum.map(tokens, &Integer.parse/1)

        case parsed do
          [{_size, ""}, {frames, ""}, {width, ""}, {height, ""}, {num, ""}, {den, ""}] ->
            %{animated?: frames > 1, dimensions: {width, height}, duration: num / den}

          _other ->
            require Logger
            Logger.warning("mediastat returned non-integer output for #{file}: #{inspect(output)}")
            %{animated?: false, dimensions: {0, 0}, duration: 0.0}
        end

      _ ->
        %{animated?: false, dimensions: {0, 0}, duration: 0.0}
    end
  end
end
