defmodule Philomena.Users.UserNotifier do
  alias Swoosh.Email
  alias Philomena.Mailer

  defp deliver(to, subject, body) do
    Email.new(
      to: {to, to},
      subject: subject,
      text_body: body
    )
    |> Mailer.format_message()
    |> Mailer.deliver()
  end

  @doc """
  Deliver instructions to confirm BeastForge account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions for your BeastForge account", """

    ==============================

    Hi #{user.name},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    Sincerely,
    The BeastForge team.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset password for a BeastForge account.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Password reset instructions for your BeastForge account", """

    ==============================

    Hi #{user.name},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    Sincerely,
    The BeastForge team.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reactivate a deactivated BeastForge account.
  """
  def deliver_reactivation_instructions(user, url) do
    deliver(user.email, "Reactivation instructions for your BeastForge account", """

    ==============================

    Hi,

    Your account has been deactivated. If you wish to re-activate it, please click the following link:

    #{url}

    Sincerely,
    The BeastForge team.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a BeastForge account email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Email update instructions for your BeastForge account", """

    ==============================

    Hi #{user.name},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    Sincerely,
    The BeastForge team.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to unlock a BeastForge account.
  """
  def deliver_unlock_instructions(user, url) do
    deliver(user.email, "Unlock instructions for your BeastForge account", """

    ==============================

    Hi #{user.name},

    Your account has been automatically locked due to too many attempts to sign in.

    You can unlock your account by visiting the URL below:

    #{url}

    Sincerely,
    The BeastForge team.

    ==============================
    """)
  end
end
