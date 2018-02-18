defmodule Coherence.SocketService do

  use Coherence.Config

  @type changeset :: Ecto.Changeset.t
  @type schema :: Ecto.Schema.t
  @type socket :: Phoenix.Socket.t

  @endpoint Module.concat(Config.web_module, Endpoint)

  @spec broadcast(String.t, Map.t) :: :ok
  def broadcast(event, data) do
    if not is_nil(Config.feedback_channel), do:
      apply(@endpoint, broadcast, [ Config.feedback_channel, event, data ])
    :ok
  end

  @spec return_ok(socket, String.t) :: {:reply, {:ok, Map.t}, socket}
  def return_ok(socket, flash), do: {:reply, {:ok, %{flash: flash}}, socket}

  @spec return_error(socket, String.t) :: {:reply, {:error, Map.t}, socket}
  def return_error(socket, flash), do: {:reply, {:error, %{flash: flash}}, socket}

  @spec return_errors(socket, changeset) :: {:reply, {:error, Map.t}, socket}
  def return_error(socket, changeset), do:
    {:reply, {:error, %{errors: error_map(changeset)}}, socket}

  @spec format_user(schema) :: Map.t
  def format_user(user) do
    blocked   = if user.blocked_at,   do: true, else: false
    confirmed = if user.confirmed_at, do: true, else: false

    %{
      admin:      user.admin,
      blocked:    blocked,
      confirmed:  confirmed,
      email:      user.email,
      id:         user.id,
      inserted_at: NaiveDateTime.to_iso8601(user.inserted_at) <> "Z",
      name:       user.name
    }
  end

  # Generates a map with all invalid fields and their first error
  defp error_map(changeset), do:
    Map.new(changeset.errors, fn ({k, v}) -> {k, elem(v, 0)} end)
end
