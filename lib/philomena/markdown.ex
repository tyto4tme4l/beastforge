defmodule Philomena.Markdown do
  @markdown_chars ~r/[\*_\[\]\(\)\^`\%\\~<>#\|]/

  @doc """
  Converts user-input Markdown to HTML, with the specified map of image
  replacements (which converts ">>1234p" syntax to an embedded image).
  """
  @spec to_html(String.t(), %{String.t() => String.t()}) :: String.t()
  def to_html(text, replacements) do
    text
    |> Philomena.Native.markdown_to_html(replacements)
    |> postprocess_sections()
  end

  @doc """
  Converts trusted-input Markdown to HTML, with the specified map of image
  replacements (which converts ">>1234p" syntax to an embedded image). This
  function does not strip any raw HTML embedded in the document.
  """
  @spec to_html_unsafe(String.t(), %{String.t() => String.t()}) :: String.t()
  def to_html_unsafe(text, replacements) do
    text
    |> Philomena.Native.markdown_to_html_unsafe(replacements)
    |> postprocess_sections()
  end

  @doc """
  Renders a line-by-line diff between two Markdown sources as an HTML table.
  """
  @spec to_html_diff(String.t(), String.t()) :: String.t()
  def to_html_diff(old, new),
    do: Philomena.Native.markdown_diff_to_html(old, new)

  @doc """
  Escapes special characters in text which is to be rendered as Markdown.
  """
  @spec escape(String.t()) :: String.t()
  def escape(text) do
    @markdown_chars
    |> Regex.replace(text, fn m ->
      "\\#{m}"
    end)
  end

  # Transforms DText [section=Title]...[/section] into native HTML5 <details>,
  # while skipping anything inside <pre>...</pre> or <code>...</code> blocks.
  defp postprocess_sections(html) when is_binary(html) do
    code_regex = ~r/(<pre\b[^>]*>.*?<\/pre>|<code\b[^>]*>.*?<\/code>)/is

    code_regex
    |> Regex.split(html, include_captures: true)
    |> Enum.map_join(fn chunk ->
      if Regex.match?(code_regex, chunk) do
        chunk
      else
        replace_section_tags(chunk)
      end
    end)
  end

  defp postprocess_sections(other), do: other

  defp replace_section_tags(chunk) do
    open_regex =
      ~r/<p>\s*\[section(?:,(?:open|expanded))?(?:=[^\]]+)?\]\s*<\/p>|\[section(?:,(?:open|expanded))?(?:=[^\]]+)?\](?:\s*<br\s*\/?>)?/i

    close_regex =
      ~r/<p>\s*\[\/section\]\s*<\/p>|(?:\s*<br\s*\/?>)?\[\/section\]/i

    chunk
    |> String.replace(open_regex, fn match ->
      is_open = if Regex.match?(~r/\[section,(?:open|expanded)/i, match), do: " open", else: ""

      title =
        case Regex.run(~r/=([^\]]+)\]/, match) do
          [_, raw_title] ->
            case String.trim(raw_title) do
              "" -> "Details"
              t -> escape_title(t)
            end

          _ ->
            "Details"
        end

      ~s(<details#{is_open} class="dtext-section"><summary class="dtext-section-title">#{title}</summary><div class="dtext-section-body">)
    end)
    |> String.replace(close_regex, "</div></details>")
  end

  defp postprocess_sections(other), do: other

  defp escape_title(title) do
    title
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
