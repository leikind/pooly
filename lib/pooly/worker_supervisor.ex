defmodule Pooly.WorkerSupervisor do
  @moduledoc false

  use DynamicSupervisor

  def start_link(pool_name) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: via(pool_name))
  end

  def init(_) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 5,
      max_seconds: 5
    )
  end

  def start_child(sup, {m, _, _} = mfa) do
    # Setting restart to :temporary because Pooly.Server will restart it
    # so here we will just let it die
    spec = %{id: m, start: mfa, restart: :temporary}
    DynamicSupervisor.start_child(sup, spec)
  end

  def name(pool_name), do: {pool_name, "supervisor-of-workers"}
  def via(pool_name), do: {:via, Registry, {PoolRegistry, name(pool_name)}}
end
