defmodule Coherence.InvitationService do
  @moduledoc """
  """
  use Coherence.Config

  # Get the configured invitation url
  def invitation_url(token), do:
    apply(Module.concat(Config.web_module, Endpoint), :url, [])
      <> Config.inviteable_path <> "/" <> token
end