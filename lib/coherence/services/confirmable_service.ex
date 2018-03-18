defmodule Coherence.ConfirmableService do
  @moduledoc """
  Confirmable allows users to confirm a new account.

  When enabled, newly created accounts are emailed send a confirmation
  email with a confirmation link. Clicking on the confirmation link enables
  the account.

  Access to the account is disabled until the account is enabled, unless the
  the `allow_unconfirmed_access_for` option is configured. If the account is
  not confirmed before the `confirmation_token_expire_days` configuration days
  expires, a new confirmation must be sent.

  Confirmable adds the following database columns to the user model:

  * :confirmation_token - a unique token required to confirm the account
  * :confirmed_at - time and date the account was confirmed
  * :confirmation_sent_at - the time and date the confirmation token was created

  The following configuration is used to customize confirmable behavior:

  * :confirmation_token_expire_days  - number days to allow confirmation. default 5 days
  * :allow_unconfirmed_access_for - number of days to allow login access to the account before confirmation.
  default 0 (disabled)
  """

  use Coherence.Config
  use CoherenceWeb, :service

  import Coherence.Authentication.Utils, only: [random_string: 1]
  import Coherence.EmailService
  import Coherence.Controller

  alias Coherence.{Messages, Schemas}

  defmacro __using__(opts \\ []) do
    quote do
      # import unquote(__MODULE__)
      use Coherence.Config

      alias Coherence.Schemas

      def confirmable? do
        Config.has_option(:confirmable) and
          Keyword.get(unquote(opts), :confirmable, true)
      end

      if Config.has_option(:confirmable) and
            Keyword.get(unquote(opts), :confirmable, true) do

        @doc """
        Checks if the user has been confirmed.

        Returns true if confirmed, false otherwise
        """
        def confirmed?(user) do
          !!user.confirmed_at
        end

        @doc """
        Confirm a user account.

        Adds the `:confirmed_at` datetime field on the user model.

        Returns a changeset ready for Repo.update
        """
        def confirm(user) do
          Schemas.change_user(user, %{confirmed_at: NaiveDateTime.utc_now(), confirmation_token: nil})
        end
      end
    end
  end

  @doc """
  Checks if the user has been confirmed.

  Returns true if confirmed, false otherwise
  """
  @spec confirmed?(Ecto.Schema.t) :: boolean
  def confirmed?(user) do
    for_option true, fn ->
      !!user.confirmed_at
    end
  end

  @doc """
  Checks if the confirmation token has expired.

  Returns true when the confirmation has expired.
  """
  @spec expired?(Ecto.Schema.t) :: boolean
  def expired?(user) do
    for_option fn ->
      expired?(user.confirmation_sent_at, days: Config.confirmation_token_expire_days)
    end
  end

  @doc """
  Checks if the user can access the account before confirmation.

  Returns true if the unconfirmed access has not expired.
  """
  @spec unconfirmed_access?(Ecto.Schema.t) :: boolean
  def unconfirmed_access?(user) do
    for_option fn ->
      case Config.allow_unconfirmed_access_for do
        0 -> false
        days -> not expired?(user.confirmation_sent_at, days: days)
      end
    end
  end

  @doc """
  Send confirmation email with token.
  If the user supports confirmable, generate a token and send the email.
  """
  @spec send_confirmation(Ecto.Schema.t) :: {:ok, String.t} | {:error, String.t}
  def send_confirmation(user) do
    user_schema = Config.user_schema
    if user_schema.confirmable? do
      token = random_string 48
      dt = NaiveDateTime.utc_now()
      user
      |> user_schema.changeset(%{
          confirmation_token: token,
          confirmation_sent_at: dt,
          current_password: user.password
        })
      |> Config.repo.update!

      if Config.mailer?() do
        send_user_email :confirmation, user, confirmation_url(token)
        {:ok, Messages.backend().confirmation_email_sent() }
      else
        {:error, Messages.backend().mailer_required() }
      end
    else
      {:ok, Messages.backend().registration_created_successfully() }
    end
  end

  defp confirmation_url(token), do:
    apply(Module.concat(Config.web_module, Endpoint), :url, [])
    <> Config.confirmable_path <> "/" <> token

  defp for_option(other \\ false, fun) do
    if Config.has_option(:confirmable), do: fun.(), else: other
  end
end