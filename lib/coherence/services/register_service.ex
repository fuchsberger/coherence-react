defmodule Coherence.RegisterService do

  use Coherence.Config
  use CoherenceWeb, :service

  import Coherence.ConfirmableService, only: [send_confirmation: 1]
  import Coherence.{TrackableService, SocketService}

  alias Coherence.{Messages, Schemas}

  @type params :: Map.t
  @type socket :: Phoenix.Socket.t

  @doc """
  Create the new user account.
  Create and send a confirmation, if this option is enabled.
  Broadcasts updated user to feedback channel, if this option is enabled.
  """
  @spec create_user(socket, params) :: {:reply, {atom, Map.t}, socket}
  def create_user(socket, params) do
    case Schemas.create_user params do
      {:ok, user} ->
        broadcast("user_created", format_user(user))
        case send_confirmation(user) do
          {:ok, flash}    -> return_ok(socket, flash)
          {:error, flash} -> return_error(socket, flash)
        end
      {:error, changeset} -> return_errors(socket, changeset)
    end
  end

  @doc """
  Allows to change password, email or name though the /settings page
  """
  def update_account(socket, params) do
    case Schemas.get_user socket.assigns.user.id do
      nil -> return_error(socket, Messages.backend().invalid_request())
      user ->
        Config.user_schema.changeset(user, params, :settings)
        |> Schemas.update
        |> case do
            {:ok, user} ->
              broadcast("users_updated", %{users: [format_user(user)]})
              if params["password_current"], do:
                track_password_reset(user, Config.user_schema.trackable_table?)
              return_ok(socket, Messages.backend().account_updated_successfully())
            {:error, changeset} -> return_errors(socket, changeset)
          end
    end
  end
end