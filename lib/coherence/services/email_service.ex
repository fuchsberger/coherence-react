defmodule Coherence.EmailService do
  @moduledoc """
  Common helper functions for Coherence Controllers.
  """
  alias Coherence.Config

  require Logger

  @doc """
  Send a user email.

  Sends a user email given the module, model, and url. Logs the email for
  debug purposes.

  Note: This function uses an apply to avoid compile warnings if the
  mailer is not selected as an option.
  """
  @spec send_user_email(atom, Ecto.Schema.t, String.t) :: any
  def send_user_email(fun, model, url) do
    if Config.mailer?() do
      email = apply(Module.concat(Config.web_module, Coherence.UserEmail), fun, [model, url])
      Logger.debug fn -> "#{fun} email: #{inspect email}" end
      apply(Module.concat(Config.web_module, Coherence.Mailer), :deliver, [email])
    else
      {:error, :no_mailer}
    end
  end
end