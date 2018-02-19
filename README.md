# Coherence React

> This version is in active development. The Readme will be updated soon.
>

Coherence React is a full featured, configurable authentication system for
applications using the [react.js](https://reactjs.org/) frontend framework with
[Phoenix](http://phoenixframework.org/).
It is based on [Coherence](https://github.com/smpallen99/coherence).

## Changes to Original

### Config
`coherence-react` has a few new (optional) config options:
```
# %% Coherence Configuration %%   Don't remove this line
config :coherence,
  [...]
  confirm_user_path: "/account/confirm",
  password_reset_path: "/account/reset_password",
  feedback_channel: nil
```
 * `feedback_channel` if set to a string, broadcasts events such as creating or
   updating users to the given channel. Defaults to: `nil`
 * `confirm_user_path` path in emails send to confirm account. This should not
   include url or token. The final url will look like: `protocol://url/path/:token`
   Defaults to: `"/account/confirm"`
 * `password_reset_path` path in emails send to reset password. This should not
   include url or token. The final url will look like: `protocol://url/path/:token`
   Defaults to: `"/account/reset_password"`

### Other changes
 * functions that were depriciated in Coherence `0.5.1` are removed from this repository

## License

`coherence` is Copyright (c) 2016-2017 E-MetroTel

`coherence-react` is Copyright (c) 2018 Alexander Fuchsberger

The source is released under the MIT License.

Check [LICENSE](LICENSE) for more information.