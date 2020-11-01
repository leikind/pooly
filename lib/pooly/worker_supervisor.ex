defmodule Pooly.WorkerSupervisor do
  @moduledoc false

  use DynamicSupervisor

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, nil)
  end

  def init(_) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 5,
      max_seconds: 5
    )
  end

  def start_child(sup, {m, _, _} = mfa) do
    spec = %{id: m, start: mfa}
    DynamicSupervisor.start_child(sup, spec)
  end
end
