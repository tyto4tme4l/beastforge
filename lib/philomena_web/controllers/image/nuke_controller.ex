defmodule PhilomenaWeb.Image.NukeController do
  use PhilomenaWeb, :controller

  alias Philomena.Images
  alias Philomena.Images.Image

  plug :verify_authorized

  def create(conn, %{"image_id" => id}) do
    image = Images.get_image!(id)
    user = conn.assigns.current_user

    case Images.nuke_image(image, user) do
      {:ok, _destroyed} ->
        conn
        |> moderation_log(
          details: &log_details/2,
          data: %{image_id: id, user: user}
        )
        |> put_flash(:notice, "Image ##{id} was completely nuked (hash cleared and permanently destroyed).")
        |> redirect(to: ~p"/images/#{id}")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to nuke image: #{inspect(reason)}")
        |> redirect(to: ~p"/images/#{id}")
    end
  end

  defp verify_authorized(conn, _opts) do
    user = conn.assigns.current_user

    # Directly verify staff/admin role to prevent Canada struct mismatches
    if user && (user.role in ["admin", "moderator"] or user.senior_staff) do
      conn
    else
      conn
      |> put_flash(:error, "You are not authorized to nuke images.")
      |> redirect(to: ~p"/images")
      |> halt()
    end
  end

  defp log_details(_action, data) do
    %{
      body: "Nuked image ##{data.image_id}",
      subject_path: ~p"/profiles/#{data.user}"
    }
  end
end
