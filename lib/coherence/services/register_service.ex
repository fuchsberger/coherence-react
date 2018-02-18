defmodule Coherence.RegisterService do

  use Coherence.Config
  use CoherenceWeb, :service

  import Coherence.TrackableService
  import Coherence.Authentication.Utils, only: [error_map: 1]

  alias Coherence.{Messages, Schemas}

  @type params :: Map.t
  @type schema :: Ecto.Schema.t
  @type socket :: Phoenix.Socket.t

  @spec create_user(socket, params) :: {:reply, {atom, Map.t, socket}
  def create_user(socket, params) do
    case Schemas.create_user params do
      {:ok, user} ->
        if not is_nil Config.feedback_channel, do: Config.endpoint.broadcast(
          Config.feedback_channel,
          "user_created",
          format_user(user)
        )
        case send_confirmation(user) do
          {:ok, flash}    -> {:reply, {:ok,    %{flash: flash}}, socket}
          {:error, flash} -> {:reply, {:error, %{flash: flash}}, socket}
        end
      {:error, changeset} ->
        {:reply, {:error, %{errors: error_map(changeset)}}, socket}
    end
  end

  @doc """
  Allows to change password, email or name though the /settings page
  """
  def update_account(socket, params) do
    if Map.has_key?(socket.assigns, :user) do
      case Schemas.get_user socket.assigns.user.id do
        nil ->
          {:reply, {:error, %{ flash: "Account does not exist." }}, socket}
        user ->
          Config.user_schema.changeset(user, params, :settings)
          |> Schemas.update
          |> case do
              {:ok, user} ->
                if params["password_current"], do:
                  track_password_reset(user, Config.user_schema.trackable_table?)
                {:reply, {:ok, %{ flash: "User was successfully updated" }}, socket}

              {:error, changeset} ->
                {:reply, {:error, %{ errors: error_map(changeset) }}, socket}
            end
      end
    else
      {:reply, {:error, %{ flash: "You are not authentificated." }}, socket}
    end
  end

  defp format_user(user) do
    blocked   = if user.blocked_at,   do: true, else: false
    confirmed = if user.confirmed_at, do: true, else: false

    %{
      admin:      user.admin,
      blocked:    blocked,
      confirmed:  confirmed,
      email:      user.email,
      id:         user.id,
      inserted_at: NaiveDateTime.to_iso8601(u.inserted_at) <> "Z",
      name:       user.name
    }
  end
end
