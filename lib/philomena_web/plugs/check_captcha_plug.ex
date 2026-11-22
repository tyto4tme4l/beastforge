defmodule PhilomenaWeb.CheckCaptchaPlug do
  import Plug.Conn
  import Phoenix.Controller

  def init([]), do: false

  def call(conn, _opts) do
    if captcha_enabled?() do
      maybe_check_captcha(conn, conn.assigns.current_user)
    else
      conn
    end
  end

  defp maybe_check_captcha(conn, nil) do
    token = extract_captcha_token(conn.params)

    if token && verify_turnstile(token) do
      conn
    else
      conn
      |> put_flash(
        :error,
        "There was an error verifying you're not a robot. Please try again."
      )
      |> do_failure_response(conn.assigns.ajax?)
      |> halt()
    end
  end

  defp maybe_check_captcha(conn, _user), do: conn

  # Extracts token from cf-turnstile-response or h-captcha-response,
  # checking both top-level params and nested forms (image, tagging, etc.)
  defp extract_captcha_token(params) when is_map(params) do
    params["cf-turnstile-response"] ||
      params["h-captcha-response"] ||
      find_nested_token(params)
  end
  defp extract_captcha_token(_), do: nil

  defp find_nested_token(params) do
    Enum.find_value(params, fn
      {_k, %{} = nested} -> extract_captcha_token(nested)
      _ -> nil
    end)
  end

  defp verify_turnstile(captcha_token) do
    case PhilomenaProxy.Http.post(
           "https://challenges.cloudflare.com/turnstile/v0/siteverify",
           URI.encode_query(%{"response" => captcha_token, "secret" => hcaptcha_secret_key()}),
           [{"Content-Type", "application/x-www-form-urlencoded"}]
         ) do
      {:ok, %{body: body, status: 200}} ->
        body
        |> JSON.decode!()
        |> Map.get("success", false)

      _error ->
        false
    end
  end

  defp do_failure_response(conn, true) do
    conn
    |> put_status(:multiple_choices)
    |> text("")
  end

  defp do_failure_response(conn, _false) do
    redirect(conn, external: conn.assigns.referrer)
  end

  def captcha_enabled? do
    Application.get_env(:philomena, :captcha) != false
  end

  def hcaptcha_secret_key do
    Application.get_env(:philomena, :hcaptcha_secret_key)
  end
end
