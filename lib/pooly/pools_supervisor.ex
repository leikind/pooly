defmodule Pooly.PoolsSupervisor do
  @moduledoc false
  use Supervisor
  alias Pooly.OnePoolSupervisor

  def start_link do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    pool_config1 = %{
      pool_name: "pool-1",
      mfa: {SampleWorker, :start_link, []},
      size: 3,
      max_overflow: 2
    }

    pool_config2 = %{
      pool_name: "pool-2",
      mfa: {SampleWorker, :start_link, []},
      size: 5,
      max_overflow: 1
    }

    children = [
      %{
        id: Sup1,
        start: {OnePoolSupervisor, :start_link, [pool_config1]},
        type: :supervisor
      },
      %{
        id: Sup2,
        start: {OnePoolSupervisor, :start_link, [pool_config2]},
        type: :supervisor
      }
    ]

    children |> Supervisor.init(strategy: :one_for_one)
  end
end
