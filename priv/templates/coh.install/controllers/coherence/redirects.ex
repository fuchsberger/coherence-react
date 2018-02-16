defmodule Coherence.Redirects do
  @moduledoc """
  Define controller action redirection functions.

  This module contains default redirect functions for each of the controller
  actions that perform redirects. By using this Module you get the following
  functions:

  * session_create/2
  * session_delete/2

  You can override any of the functions to customize the redirect path. Each
  function is passed the `conn` and `params` arguments from the controller.

  """
  use Redirects
  # Uncomment the import below if adding overrides
  # import <%= web_base %>.Router.Helpers

  # Add function overrides below

  # Example usage

  # def session_create(conn, _), do: redirect(conn, to: "/dashboard")
  # def session_delete(conn, _), do: redirect(conn, to: "/login")

end
