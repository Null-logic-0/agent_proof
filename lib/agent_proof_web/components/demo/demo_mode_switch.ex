defmodule AgentProofWeb.DemoModeSwitch do
  use AgentProofWeb, :html

  @doc """
  Button that turns Demo Mode on or off for this browser.
  """
  attr :id, :string, required: true
  attr :demo_mode, :boolean, required: true, doc: "whether Demo Mode is on now"
  attr :return_to, :string, required: true, doc: "the page to reload afterwards"
  attr :class, :any, default: nil
  attr :rest, :global, doc: "extra button attributes, e.g. aria-pressed"
  slot :inner_block, required: true

  def demo_mode_switch(assigns) do
    ~H"""
    <.form for={%{}} id={@id} action={~p"/demo-mode"} method="post">
      <input type="hidden" name="demo_mode" value={if @demo_mode, do: "off", else: "on"} />
      <input type="hidden" name="return_to" value={@return_to} />
      <button type="submit" id={"#{@id}-button"} class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
    </.form>
    """
  end
end
