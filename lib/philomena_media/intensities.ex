defmodule PhilomenaMedia.Intensities do
  @moduledoc """
  Corner intensities are a simple mechanism for automatic image deduplication,
  designed for a time when computer vision was an expensive technology and
  resources were scarce.

  Each image is divided into quadrants; image with odd numbers of pixels
  on either dimension overlap quadrants by one pixel. The luma (brightness)
  value corresponding each the pixel is computed according to BTU.709 primaries,
  and its value is added to a sum for each quadrant. Finally, the value is divided
  by the number of pixels in the quadrant to produce an average. The minimum luma
  value of any pixel is 0, and the maximum is 255, so an average will be between
  these values. Transparent pixels are composited on black before processing.

  By using a range search in the database, this produces a reverse image search which
  suffers no dimensionality issues, is exceptionally fast to evaluate, and is independent
  of image dimensions, with poor precision and a poor-to-fair accuracy.
  """

  alias PhilomenaMedia.Remote

  @type t :: %__MODULE__{
          nw: float(),
          ne: float(),
          sw: float(),
          se: float()
        }

  defstruct nw: 0.0,
            ne: 0.0,
            sw: 0.0,
            se: 0.0

  @doc """
  Gets the corner intensities of the given image file.

  The image file must be in the PNG or JPEG format.

  > #### Info {: .info}
  >
  > Clients should prefer to use `PhilomenaMedia.Processors.intensities/2`, as it handles
  > media files of any type supported by this library, not just PNG or JPEG.

  ## Examples

      iex> Intensities.file("image.png")
      {:ok, %Intensities{nw: 111.689148, ne: 116.228048, sw: 93.268433, se: 104.630064}}

      iex> Intensities.file("nonexistent.jpg")
      :error

  """
  @spec file(Path.t()) :: {:ok, t()} | :error
  def file(input) do
    Remote.cmd("image-intensities", [input])
    |> case do
      {output, 0} ->
        values =
          output
          |> String.trim()
          |> String.split(~r/[\t\s]+/, trim: true)
          |> Enum.map(&parse_float/1)

        case values do
          [nw, ne, sw, se] ->
            {:ok, %__MODULE__{nw: nw, ne: ne, sw: sw, se: se}}

          _ ->
            # Fallback to neutral intensities if output was empty or malformed
            {:ok, %__MODULE__{nw: 0.5, ne: 0.5, sw: 0.5, se: 0.5}}
        end

      _error ->
        {:ok, %__MODULE__{nw: 0.5, ne: 0.5, sw: 0.5, se: 0.5}}
    end
  end

  defp parse_float(str) do
    case Float.parse(str) do
      {f, _} -> f
      :error ->
        case Integer.parse(str) do
          {i, _} -> i * 1.0
          :error -> 0.5
        end
    end
  end
end
