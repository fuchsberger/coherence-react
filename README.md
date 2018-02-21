# Coherence React

> This version is in active development. The Readme will be updated soon.
>

Coherence React is a full featured, configurable authentication system for
applications using the [react.js](https://reactjs.org/) frontend framework with
[Phoenix](http://phoenixframework.org/).
It is based on [Coherence](https://github.com/smpallen99/coherence).

## Installation
Coherence-React privides a SPA-frontend with react-router and channel management.
Install like in the original. Instead of controller/view/template files,
coherence-react will install js files, according to the install options.

## Installation

  1. Add coherence to your list of dependencies in `mix.exs`:

```elixir
  def deps do
    [
      ...
      {:coherence, github: "sathras/coherence-react"}
    ]
  end
```

  2. Ensure coherence is started before your application:

```elixir
  def application do
    extra_applications: [..., :coherence]]
  end
```

  3. Install coherence files and options
```
  mix coh.install --full
```
**Attention!**
  * `--full` now means all options! (including confirmable, inviteable, active-user-fied)
  * router.ex will be properly replaced. (back up your content!)

## Usage

### Channels
The following events can be added to any channel:
```elixir
  import Coherence.Socket

  # administerable
  def handle_in("update_users", params, socket), do: update_users socket, params # 1)
  def handle_in("delete_users", params, socket), do: delete_users socket, params # 1)

  # confirmable
  def handle_in("create_confirmation", params, socket), do: create_confirmation socket, params
  def handle_in("handle_confirmation", params, socket), do: handle_confirmation socket, params

  # inviteable
  def handle_in("create_invitations", params, socket), do: create_invitations socket, params
  def handle_in("delete_invitations", params, socket), do: delete_invitations socket, params

  # recoverable
  def handle_in("create_recover", params, socket), do: create_recover socket, params
  def handle_in("handle_recover", params, socket), do: handle_recover socket, params

  # registable
  def handle_in("create_user", params, socket), do: create_user socket, params
  def handle_in("update_user", params, socket), do: update_user socket, params # 2)

  # unlockable
  def handle_in("create_unlock", params, socket), do: create_unlock socket, params
  def handle_in("handle_unlock", params, socket), do: handle_unlock socket, params
```
  1) if `socket.assigns.user` he will be excluded from query
  2) only works if `socket.assigns.user != nil`

If the given option is installed and set in config, these functions provide the same
functionality as the matching coherence controller actions (create, update, delete).
Usually functions reply with `{:ok, %{flash: message}}` or `{:error, %{flash: message}}`.
Changeset errors are returned with `{:error, %{errors: %{field: String.t}}}`

### Config
`coherence-react` has a few new (optional) config options:
```elixir
config :coherence,
  confirmable_path: "/account/confirm",
  recoverable_path: "/account/reset_password",
  unlock_path:      "/account/unlock"
  feedback_channel: nil
```
 * `confirmable_path` path in emails send to confirm account. This should not
   include url or token. The final url will look like: `protocol://url/path/:token`
   Defaults to: `"/account/confirm"`
 * `recoverable_path` path in emails send to reset password. This should not
   include url or token. The final url will look like: `protocol://url/path/:token`
   Defaults to: `"/account/reset_password"`
 * `unlock_path` path in emails send to unlock acocunt. This should not
   include url or token. The final url will look like: `protocol://url/path/:token`
   Defaults to: `"/account/unlock"`
 * `feedback_channel` if set to a string, broadcasts events such as creating or
   updating users to the given channel. Affects successful create and update user events.
   Defaults to: `nil`

### Other changes
 * functions that were depreciated in Coherence `0.5.1` are removed from this repository

## License

`coherence` is Copyright (c) 2016-2017 E-MetroTel

`coherence-react` is Copyright (c) 2018 Alexander Fuchsberger

The source is released under the MIT License.

Check [LICENSE](LICENSE) for more information.