defmodule PhilomenaWeb.CaptchaPlug do
  alias PhilomenaWeb.ContentSecurityPolicyPlug

  @turnstile_url ["https://challenges.cloudflare.com"]

  def init(_opts), do: []

  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    user = conn.assigns.current_user
    maybe_assign_csp_headers(conn, user)
  end

  defp maybe_assign_csp_headers(conn, nil) do
    conn
    |> ContentSecurityPolicyPlug.permit_source(:script_src, @turnstile_url)
    |> ContentSecurityPolicyPlug.permit_source(:frame_src, @turnstile_url)
    |> ContentSecurityPolicyPlug.permit_source(:style_src, @turnstile_url)
  end

  defp maybe_assign_csp_headers(conn, _user), do: conn
end
