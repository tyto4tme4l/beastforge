defmodule Philomena.Markdown do
  @markdown_chars ~r/[\*_\[\]\(\)\^`\%\\~<>#\|]/

  @doc """
  Converts user-input Markdown to HTML, with the specified map of image
  replacements (which converts ">>1234p" syntax to an embedded image).
  """
  @spec to_html(String.t(), %{String.t() => String.t()}) :: String.t()
  def to_html(text, replacements) do
    text
    |> pad_section_lines()
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
    |> pad_section_lines()
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

  # Ensures standalone [section] / [/section] lines outside fenced code blocks
  # sit in their own <div class="paragraph"> so multi-paragraph sections stay valid.
  defp pad_section_lines(text) when is_binary(text) do
    section_line_re =
      ~r/^\s*(\[section(?:,(?:open|expanded))?(?:=[^\]]+)?\]|\[\/section\])\s*$/i

    text
    |> String.split("\n")
    |> Enum.reduce({false, []}, fn line, {in_fence?, acc} ->
      trimmed = String.trim_leading(line)
      toggles_fence? = String.starts_with?(trimmed, "```") or String.starts_with?(trimmed, "~~~")
      next_fence? = if toggles_fence?, do: not in_fence?, else: in_fence?

      out_line =
        if not in_fence? and Regex.match?(section_line_re, line) do
          "\n" <> String.trim(line) <> "\n"
        else
          line
        end

      {next_fence?, [out_line | acc]}
    end)
    |> elem(1)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  # Stack-balanced [section=Title]...[/section] transformer that skips <pre> and <code> blocks
  # and leaves unmatched opening/closing tags as literal text so layout HTML can never break.
  defp postprocess_sections(html) when is_binary(html) do
    code_regex = ~r/(<pre\b[^>]*>.*?<\/pre>|<code\b[^>]*>.*?<\/code>)/is

    token_regex =
      ~r/<div class="paragraph">\s*\[section(?:,(?:open|expanded))?(?:=[^\]]+)?\]\s*<\/div>|\[section(?:,(?:open|expanded))?(?:=[^\]]+)?\]|<div class="paragraph">\s*\[\/section\]\s*<\/div>|\[\/section\]/i

    code_regex
    |> Regex.split(html, include_captures: true)
    |> Enum.reduce([%{type: :root, buf: []}], fn chunk, stack ->
      cond do
        chunk == "" ->
          stack

        Regex.match?(code_regex, chunk) ->
          [top | rest] = stack
          [%{top | buf: [chunk | top.buf]} | rest]

        true ->
          token_regex
          |> Regex.split(chunk, include_captures: true)
          |> Enum.reduce(stack, fn part, acc_stack ->
            process_section_part(part, acc_stack)
          end)
      end
    end)
    |> unwind_unclosed()
  end

  defp process_section_part("", stack), do: stack

  defp process_section_part(part, stack) do
    cond do
      Regex.match?(~r/^(?:<div class="paragraph">\s*)?\[section/i, part) ->
        is_open = Regex.match?(~r/\[section,(?:open|expanded)/i, part)

        title =
          case Regex.run(~r/\[section(?:,(?:open|expanded))?=([^\]]+)\]/i, part) do
            [_, raw_title] ->
              case String.trim(raw_title) do
                "" -> "Details"
                t -> escape_title(t)
              end

            _ ->
              "Details"
          end

        [%{type: :section, open: is_open, title: title, raw: part, buf: []} | stack]

      Regex.match?(~r/^(?:<div class="paragraph">\s*)?\[\/section\]/i, part) ->
        case stack do
          [%{type: :section} = frame, parent | rest] ->
            inner =
              frame.buf
              |> Enum.reverse()
              |> IO.iodata_to_binary()
              |> String.replace(~r/^\s*<br\s*\/?>\s*/i, "")
              |> String.replace(~r/\s*<br\s*\/?>\s*$/i, "")

            open_attr = if frame.open, do: " open", else: ""

            html =
              ~s(<details#{open_attr} class="dtext-section"><summary class="dtext-section-title">#{frame.title}</summary><div class="dtext-section-body">#{inner}</div></details>)

            [%{parent | buf: [html | parent.buf]} | rest]

          _ ->
            # Unmatched [/section]: leave literal instead of emitting stray closing tags
            [top | rest] = stack
            [%{top | buf: [part | top.buf]} | rest]
        end

      true ->
        [top | rest] = stack
        [%{top | buf: [part | top.buf]} | rest]
    end
  end

  defp unwind_unclosed([%{type: :root, buf: buf}]) do
    buf |> Enum.reverse() |> IO.iodata_to_binary()
  end

  defp unwind_unclosed([%{type: :section} = frame, parent | rest]) do
    # Unclosed [section]: restore literal opening tag + its content so HTML remains valid
    inner = frame.buf |> Enum.reverse() |> IO.iodata_to_binary()
    unwind_unclosed([%{parent | buf: [inner, frame.raw | parent.buf]} | rest])
  end

  defp escape_title(title) do
    title
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
