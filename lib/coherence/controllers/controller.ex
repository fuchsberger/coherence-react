defmodule Coherence.Controller do
  @moduledoc """
  Common helper functions for Coherence Controllers.
  """
  import Phoenix.Controller, only: [put_layout: 2, put_view: 2]

  alias Coherence.{Config, RememberableService, TrackableService, Messages}

  require Logger

  @type schema :: Ecto.Schema.t
  @type changeset :: Ecto.Changeset.t
  @type schema_or_error :: schema | {:error, changeset}
  @type conn :: Plug.Conn.t
  @type params :: Map.t

  @doc """
  Get the configured logged_out_url.
  """
  @spec logged_out_url() :: String.t
  def logged_out_url() do
    Config.logged_out_url || "/"
  end

  @doc """
  Get the configured logged_in_url.
  """
  @spec logged_in_url() :: String.t
  def logged_in_url() do
    Config.logged_in_url || "/"
  end

  @doc """
  Put LayoutView

  Adds Config.layout if set.
  """
  @spec layout_view(Plug.Conn.t, Keyword.t) :: Plug.Conn.t
  def layout_view(conn, opts) do
    case opts[:layout] || Config.layout() do
      nil ->
        mod = (opts[:caller] || None) |> Module.split |> hd
        check_for_coherence(conn, mod)
      layout ->
        put_layout conn, layout
    end
    |> set_view(opts)
  end

  defp check_for_coherence(conn, "Coherence") do
    put_layout conn, {Module.concat(Config.web_module, LayoutView), :app}
  end
  defp check_for_coherence(conn, _), do: conn

  @doc """
  Set view plug
  """
  @spec set_view(Plug.Conn.t, Keyword.t) :: Plug.Conn.t
  def set_view(conn, opts) do
    case opts[:view] do
      nil -> conn
      view -> put_view conn, Module.concat(Config.web_module, view)
    end
  end

  @doc """
  Get the Router.Helpers module for the project..

  Returns the projects Router.Helpers module.
  """
  @spec router_helpers() :: module
  def router_helpers do
    Module.concat(Config.router(), Helpers)
  end

  @doc """
  Test if a datetime has expired.

  Convert the datetime from NaiveDateTime format to Timex format to do
  the comparison given the time during in opts.

  ## Examples

      expired?(user.expire_at, days: 5)
      expired?(user.expire_at, minutes: 10)

      iex> NaiveDateTime.utc_now()
      ...> |> Coherence.Controller.expired?(days: 1)
      false

      iex> NaiveDateTime.utc_now()
      ...> |> Coherence.Controller.shift(days: -2)
      ...> |> Coherence.Controller.expired?(days: 1)
      true
  """
  @spec expired?(nil | struct, Keyword.t) :: boolean
  def expired?(nil, _), do: true
  def expired?(datetime, opts) do
    not Timex.before?(Timex.now, shift(datetime, opts))
  end

  @doc """
  Shift a NaiveDateTime.

  ## Examples

      iex> ~N(2016-10-10 10:10:10)
      ...> |> Coherence.Controller.shift(days: -2)
      ...> |> to_string
      "2016-10-08 10:10:10Z"
  """
  @spec shift(struct, Keyword.t) :: struct
  def shift(datetime, opts) do
    datetime
    |> NaiveDateTime.to_erl
    |> Timex.to_datetime
    |> Timex.shift(opts)
  end

  @doc """
  Lock a use account.

  Sets the `:locked_at` field on the user model to the current date and time unless
  provided a value for the optional parameter.

  You can provide a date in the future to override the configured lock expiry time. You
  can set this data far in the future to do a pseudo permanent lock.
  """
  @spec lock!(Ecto.Schema.t, struct) :: schema_or_error
  def lock!(user, locked_at \\ NaiveDateTime.utc_now()) do
    user_schema = Config.user_schema
    changeset = user_schema.lock user, locked_at
    if user_schema.locked?(user) do
      changeset = Ecto.Changeset.add_error changeset, :locked_at, Messages.backend().already_locked()
      {:error, changeset}
    else
      changeset
      |> Config.repo.update
    end
  end

  @spec redirect_to(conn, atom, params) :: conn
  def redirect_to(conn, path, params) do
    apply(Coherence.Redirects, path, [conn, params])
  end

  @spec redirect_to(conn, atom, params, schema) :: conn
  def redirect_to(conn, path, params, user) do
    apply(Coherence.Redirects, path, [conn, params, user])
  end

  def respond_with(conn, atom, opts \\ %{}) do
    responder = case conn.private.phoenix_format do
      "json" ->
        Coherence.Responders.Json
      _ ->
        Coherence.Responders.Html
    end
    apply(responder, atom, [conn, opts])
  end

  @spec changeset(atom, module, schema, params) :: changeset
  def changeset(which, module, model, params \\ %{})
  def changeset(:password, module, model, params) do
    fun = Application.get_env :coherence, :changeset, :changeset
    apply module, fun, [model, params, :password]
  end
  def changeset(which, module, model, params) do
    {mod, fun, args} = case Application.get_env :coherence, :changeset do
      nil -> {module, :changeset, [model, params]}
      {mod, fun} -> {mod, fun, [model, params, which]}
    end
    apply mod, fun, args
  end

  @doc """
  Deactivate a user.

  Removes all logged in sessions for a user.
  """
  @spec deactivate_user(conn) :: conn
  def deactivate_user(conn) do
    logout_user(conn, all: Coherence.current_user(conn))
  end

  def schema_module(schema) do
    Module.concat [Config.module, Coherence, schema]
  end
end
