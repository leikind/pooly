defmodule Pooly do
  @moduledoc false

  use Application

  @timeout 5_000

  def start(_type, _args) do
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
      {Registry, keys: :unique, name: PoolRegistry},
      %{
        id: Pooly.Supervisor1,
        start: {Pooly.Supervisor, :start_link, [pool_config1]},
        type: :supervisor
      },
      %{
        id: Pooly.Supervisor2,
        start: {Pooly.Supervisor, :start_link, [pool_config2]},
        type: :supervisor
      }
    ]

    children |> Supervisor.start_link(strategy: :one_for_one, name: Pooly.TopSupervisor)
  end

  def checkout(pool_name, block \\ true, timeout \\ @timeout) do
    Pooly.Server.checkout(pool_name, block, timeout)
  end

  def checkin(pool_name, worker_pid) do
    Pooly.Server.checkin(pool_name, worker_pid)
  end

  def status(pool_name) do
    Pooly.Server.status(pool_name)
  end
end
