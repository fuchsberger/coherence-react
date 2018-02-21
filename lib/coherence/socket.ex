defmodule Coherence.Socket do

  use Coherence.Config

  import Coherence.{ConfirmableService, TrackableService}

  alias Coherence.{Messages, Schemas}

  @endpoint Module.concat(Config.web_module, Endpoint)

  @type changeset :: Ecto.Changeset.t
  @type schema :: Ecto.Schema.t
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
        broadcast "user_created", format_user(user)
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
  def edit_user(socket, params, :settings) do
    case Map.has_key(Schemas.get_user socket.assigns.user.id do
      nil -> return_error(socket, Messages.backend().invalid_request())
      user ->
        Config.user_schema.changeset(user, params, :settings)
        |> Schemas.update
        |> case do
            {:ok, user} ->
              broadcast "users_updated", %{users: [format_user(user)]}
              if params["password_current"], do:
                track_password_reset(user, Config.user_schema.trackable_table?)
              return_ok(socket, Messages.backend().account_updated_successfully())
            {:error, changeset} -> return_errors(socket, changeset)
          end
    end
  end

  @doc """
  Allows to change users, given a list of users and a list of parameters
  """
  def edit_users(socket, %{ "users" => users, "params" => params }) do

    # do not allow updates on current user
    exclude_me = current_user?(socket) and Enum.member? users, socket.assigns.user.id
    users = if exclude_me,
      do: List.delete(users, socket.assigns.user.id),
      else: users

    case Schemas.update_users(users, params) do
      {count, users} ->
        broadcast "users_updated", %{users: users}

        if exclude_me, do: return_ok socket, "You have successfully updated #{count} users! No changes were made on your account."
        else: return_ok socket, "You have successfully updated #{count} users!"
      _ ->
        return_error socket, "Something went wrong while updating a user!"
    end
  end

  defp broadcast(event, data) do
    if not is_nil(Config.feedback_channel), do:
      apply(@endpoint, :broadcast, [ Config.feedback_channel, event, data ])
    :ok
  end

  defp current_user?(socket), do: !!Map.has_key(socket.assigns, :user)

  defp return_ok(socket), do:
    {:reply, :ok, socket}

  defp return_ok(socket, flash), do:
    {:reply, {:ok, %{flash: flash}}, socket}

  defp return_error(socket), do:
    {:reply, :error, socket}

  defp return_error(socket, flash), do:
    {:reply, {:error, %{flash: flash}}, socket}

  defp return_errors(socket, changeset), do:
    {:reply, {:error, %{errors: error_map(changeset)}}, socket}

  # formats a user struct and returns a map with appropriate fields
  defp format_user(u) do
    user = %{
      id: u.id,
      email: u.email,
      name: u.name,
      inserted_at: NaiveDateTime.to_iso8601(u.inserted_at) <> "Z"
    }
    user = if administerable?(), do: Map.put(user, :admin, admin?(u)), else: user
    user = if blockable?(), do: Map.put(user, :blocked, blocked?(u)), else: user
    user = if confirmable?(), do: Map.put(user, :confirmed, confirmed?(u)), else: user
  end

  # Generates a map with all invalid fields and their first error
  defp error_map(changeset), do:
    Map.new(changeset.errors, fn ({k, v}) -> {k, elem(v, 0)} end)
end
