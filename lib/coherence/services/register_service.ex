defmodule Coherence.RegisterService do

  import Coherence.TrackableService

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
end
