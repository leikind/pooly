defmodule Pooly.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(pool_config) do
    Supervisor.start_link(__MODULE__, pool_config)
  end

  def init(pool_config) do
    children = [
      %{
        id: Pooly.Server,
        start: {Pooly.Server, :start_link, [self(), pool_config]},
        type: :worker,
        restart: :permanent
      }
    ]

    children
    |> Supervisor.init(strategy: :one_for_all)
  end
end
