defmodule Coherence.PasswordService do
  @moduledoc """
  This service handles reseting of passwords.
  Installed with the `--recoverable` installation option, this service handles
  the creation of the `reset_password_token`. With this installation option, the
  following fields are added to the user's schema:
  * :reset_password_token - A random string token generated and sent to the user
  * :reset_password_sent_at - the date and time the token was created
  The following configuration can be used to customize the behavior of the
  recoverable option:
  * :reset_token_expire_days (2) - the expiry time of the reset token in days.
  """
  use Coherence.Config

  # Get the configured password reset url (requires token)
  def password_url(token), do:
    apply(Module.concat(Config.web_module, Endpoint), :url, [])
      <> Config.recoverable_path <> "/" <> token

  def clear_password_params(params \\ %{}) do
    params
    |> Map.put("reset_password_token", nil)
    |> Map.put("reset_password_sent_at", nil)
  end
end