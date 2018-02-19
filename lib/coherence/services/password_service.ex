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

  import Coherence.{Controller, SocketService, TrackableService}
  alias Coherence.{Messages, Schemas}

  @type params :: Map.t
  @type socket :: Phoenix.Socket.t

  @doc """
  Create the recovery token and send the email
  """
  @spec create_password(socket, params) :: {:reply, {atom, Map.t}, socket}
  def create_password(socket, %{"email" => email} = params) do
    cs = Config.user_schema.changeset(params, :email)
    if Map.has_key?(error_map(cs), :email) do
      return_errors(socket, cs)
    else
      case Schemas.get_user_by_email email do
        nil ->
          return_error(socket, Messages.backend().could_not_find_that_email_address())
        user ->
          token = random_string 48
          # update database
          Config.repo.update! Config.user_schema.changeset(user, %{
            reset_password_token: token,
            reset_password_sent_at: NaiveDateTime.utc_now()
          }, :password)
          # send token via email
          if Config.mailer?() do
            send_user_email :password, user, password_url(token)
            return_ok(socket, Messages.backend().reset_email_sent())
          else
            return_error(socket, Messages.backend().mailer_required())
          end
      end
    end
  end

  @doc """
  Verify the new password and update the database
  """
  @spec update_password(socket, params) :: {:reply, {atom, Map.t}, socket}
  def update_password(socket, params) do
    user_schema = Config.user_schema
    case Schemas.get_by_user reset_password_token: params["token"] do
      nil -> return_error(socket, Messages.backend().invalid_reset_token())
      user ->
        if expired? user.reset_password_sent_at, days: Config.reset_token_expire_days do
          :password
          |> changeset(user_schema, user, clear_password_params())
          |> Schemas.update
          return_error(socket, Messages.backend().password_reset_token_expired())
        else
          params = clear_password_params params
          :password
          |> changeset(user_schema, user, params)
          |> Schemas.update
          |> case do
            {:ok, user} ->
              track_password_reset(user, user_schema.trackable_table?)
              return_ok(socket, Messages.backend().password_updated_successfully())
            {:error, changeset} ->
              return_errors(socket, changeset)
          end
        end
    end
  end

  # Get the configured password reset url (requires token)
  defp password_url(token), do:
    apply(Module.concat(Config.web_module, Endpoint), :url, [])
    <> Config.password_reset_path <> "/" <> token

  defp clear_password_params(params \\ %{}) do
    params
    |> Map.put("reset_password_token", nil)
    |> Map.put("reset_password_sent_at", nil)
  end
end
