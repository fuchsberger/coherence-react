defmodule Coherence.LockableService do
  @moduledoc """
  Lockable disables an account after too many failed login attempts.

  Enabled with the `--lockable` installation option, after 5 failed login
  attempts, the user is locked out of their account for 5 minutes.

  This option adds the following fields to the user schema:

  * :failed_attempts, :integer - The number of failed login attempts.
  * :locked_at, :datetime - The time and date when the account was locked.

  The following configuration is used to customize lockable behavior:

  * :unlock_timeout_minutes (20) - The number of minutes to wait before unlocking the account.
  * :max_failed_login_attempts (5) - The number of failed login attempts before locking the account.

  By default, a locked account will be unlocked after the `:unlock_timeout_minutes` expires or the
  is unlocked using the `unlock` API.

  In addition, the `--unlock-with-token` option can be given to the installer to allow
  a user to unlock their own account by requesting an email be sent with an link containing an
  unlock token.

  With this option installed, the following field is added to the user schema:

  * :unlock_token, :string

  """
  use Coherence.Config

  import Coherence.Socket, only: [random_string: 1]
  alias Coherence.{Controller, Schemas}

  require Logger

  @type changeset :: Ecto.Changeset.t
  @type schema :: Ecto.Schema.t
  @type schema_or_error :: schema | {:error, changeset}

  @doc false
  @spec clear_unlock_values(schema, module) :: nil | :ok | String.t
  def clear_unlock_values(user, user_schema) do
    if user.unlock_token or user.locked_at do
      schema =
        :unlock
        |> Controller.changeset(user_schema, user, %{unlock_token: nil, locked_at: nil})
        |> Schemas.update
      case schema do
        {:error, changeset} ->
          lockable_failure changeset
        _ ->
          :ok
      end
    end
  end

  @doc """
  Log an error message when lockable update fails.
  """
  @spec lockable_failure(changeset) :: :ok
  def lockable_failure(changeset) do
    Logger.error "Failed to update lockable attributes " <> inspect(changeset.errors)
  end

  def send_unlock_email(user) do
    if Config.mailer?() do
      send_user_email :unlock, user, unlock_url(user.unlock_token)
      {:ok, Messages.backend().unlock_instructions_sent() }
    else
      {:error, Messages.backend().mailer_required() }
    end
  end

  @doc """
  Unlock a user account.

  Clears the `:locked_at` field on the user model and updates the database.
  """
  @spec unlock!(schema) :: schema_or_error
  def unlock!(user) do
    user_schema = Config.user_schema
    changeset = user_schema.unlock user
    if user_schema.locked?(user) do
      Schemas.update changeset
    else
      changeset = Ecto.Changeset.add_error changeset, :locked_at, Messages.backend().not_locked()
      {:error, changeset}
    end
  end

  def unlock_token(user) do
    token = random_string 48
    [Config.module, Coherence, Schemas]
    |> Module.concat
    |> apply(Module.concat(), :update_user, [user, %{unlock_token: token}])
  end

  defp unlock_url(token), do:
    apply(Module.concat(Config.web_module, Endpoint), :url, [])
    <> Config.unlock_path <> "/" <> token
end