defmodule Coherence.Router do
  @moduledoc """
  Handles routing for Coherence.

  ## Usage

  Add the following to your `web/router.ex` file

      defmodule MyProject.Router do
        use MyProject.Web, :router
        use Coherence.Router         # Add this

        pipeline :browser do
          plug :accepts, ["html"]
          # ...
          plug Coherence.Authentication.Session           # Add this
        end

        scope "/" do
          pipe_through :browser
          coherence_routes()
          get "/*path", PageController, :index
        end
      end

  Alternatively, you may want to use the login plug in individual controllers. In
  this case, you can have one pipeline, one scope and call `coherence_routes :all`.
  In this case, it will add both the public and protected routes.
  """
  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc """
  Coherence routes macro.

  Use this function to define login/logout routes.
  All other coherence routes are handled in front-end.
  """
  defmacro coherence_routes() do
    quote do
      if Coherence.Config.has_action?(:authenticatable, :create), do:
      post "/login", Coherence.SessionController, :create

      if Coherence.Config.has_action?(:authenticatable, :delete), do:
      post "/logout", Coherence.SessionController, :delete

      # if Coherence.Config.has_action?(:authenticatable, :create), do:
      # post "/login", Coherence.SessionController, :create

      # if Coherence.Config.has_action?(:authenticatable, :delete), do:
      # post "/logout", Coherence.SessionController, :delete
    end
  end
end
