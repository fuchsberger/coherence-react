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

  defp for_option(other \\ false, fun) do
    if Config.has_option(:confirmable) do
      fun.()
    else
      other
    end
  end

  @doc """
  Send confirmation email with token.
  If the user supports confirmable, generate a token and send the email.
  """
  @spec send_confirmation(schema) :: map
  def send_confirmation(user) do
    user_schema = Config.user_schema
    if user_schema.confirmable? do
      token = random_string 48
      url = confirmation_url(token)
      dt = NaiveDateTime.utc_now()
      Logger.debug "confirmation email url: #{inspect url}"
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

  @doc """
  Resends a confirmation email with a new token to the account with given email
  """
  def confirm_account(socket, params) do
    user_schema = Config.user_schema
    validation_errors = error_map(user_schema.changeset(params, :email))
    if Map.has_key?(validation_errors, :email) do
      {:reply, {:error, %{ errors: validation_errors }}, socket}
    else
      case Schemas.get_user_by_email params["email"] do
        nil ->
          {:reply, {:error, %{
            flash: Messages.backend().could_not_find_that_email_address()
          }}, socket}
        user ->
          if user_schema.confirmed?(user) do
            {:reply, {:error, %{
              flash: Messages.backend().account_already_confirmed() }
            }, socket}
          else
            case send_confirmation(user) do
              {:ok, flash}    -> {:reply, {:ok,    %{ flash: flash }}, socket}
              {:error, flash} -> {:reply, {:error, %{ flash: flash }}, socket}
            end
          end
      end
    end
  end

  @doc """
  Handle the user's click on the confirm link in the confirmation email.
  Validate that the confirmation token has not expired and sets `confirmation_sent_at`
  field to nil, marking the user as confirmed.
  """
  def confirm_token(socket, %{"token" => token}) do
    user_schema = Config.user_schema
    case Schemas.get_by_user confirmation_token: token do
      nil ->
        {:reply, {:error, %{
          flash: Messages.backend().invalid_confirmation_token()
        }}, socket}
      user ->
        if expired? user do
          {:reply, {:error, %{
            flash: Messages.backend().confirmation_token_expired()
          }}, socket}
        else
          changeset = changeset(:confirmation, user_schema, user, %{
            confirmation_token: nil,
            confirmed_at: DateTime.utc_now,
            })
          case Config.repo.update(changeset) do
            {:ok, _user} ->
              {:reply, {:ok, %{
                flash: Messages.backend().user_account_confirmed_successfully()
              }}, socket}
            {:error, _changeset} ->
              {:reply, {:error, %{
                flash: Messages.backend().problem_confirming_user_account()
              }}, socket}
          end
        end
    end
  end

  @doc """
  Generates a map with all invalid fields and their first error
  """
  defp error_map(changeset), do:
    Map.new(changeset.errors, fn ({k, v}) -> {k, translate_error(v)} end)

  @doc """
  Translates an error message using gettext.
  """
  defp translate_error({msg, opts}) do
    # Because error messages were defined within Ecto, we must
    # call the Gettext module passing our Gettext backend. We
    # also use the "errors" domain as translations are placed
    # in the errors.po file.
    # Ecto will pass the :count keyword if the error message is
    # meant to be pluralized.
    # On your own code and templates, depending on whether you
    # need the message to be pluralized or not, this could be
    # written simply as:
    #
    #     dngettext "errors", "1 file", "%{count} files", count
    #     dgettext "errors", "is invalid"
    #
    if count = opts[:count] do
      Gettext.dngettext("default", "errors", msg, msg, count, opts)
    else
      Gettext.dgettext("default", "errors", msg, opts)
    end
  end
end