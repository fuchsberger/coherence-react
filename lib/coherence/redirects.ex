defmodule Redirects do
  @moduledoc """
  Define controller action redirection behaviour.

  Defines the default redirect functions for each of the controller
  actions that perform redirects. By using this Module you get the following
  functions:

  * session_create/2
  * session_delete/2

  You can override any of the functions to customize the redirect path. Each
  function is passed the `conn` and `params` arguments from the controller.

  ## Examples

      use Redirects
      import MyProject.Router.Helpers

      def session_create(conn, _), do: redirect(conn, to: "/dashboard")
      def session_delete(conn, _), do: redirect(conn, to: "/login")

  """
  @callback session_create(conn :: term, params :: term) :: term
  @callback session_delete(conn :: term, params :: term) :: term

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Redirects

      import Phoenix.Controller, only: [redirect: 2]
      import Coherence.Controller
      import Plug.Conn, only: [get_session: 2, put_session: 3]

      @doc false
      def session_delete(conn, _), do: redirect(conn, to: logged_out_url())

      @doc false
      def session_create(conn, _) do
        url = case get_session(conn, "user_return_to") do
          nil -> logged_in_url()
          value -> value
        end
        conn
        |> put_session("user_return_to", nil)
        |> redirect(to: url)
      end

      defoverridable [ session_create: 2, session_delete: 2 ]
    end
  end
end