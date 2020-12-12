defmodule Pooly do
  @moduledoc false

  use Application
  alias Pooly.{PoolsSupervisor, Server}

  @timeout 5_000

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: PoolRegistry},
      %{
        id: PoolsSupervisor,
        start: {PoolsSupervisor, :start_link, []},
        type: :supervisor
      }
    ]

    children |> Supervisor.start_link(strategy: :one_for_one, name: __MODULE__)
  end

  def checkout(pool_name, block \\ true, timeout \\ @timeout) do
    Server.checkout(pool_name, block, timeout)
  end

  def checkin(pool_name, worker_pid) do
    Server.checkin(pool_name, worker_pid)
  end

  def status(pool_name) do
    Server.status(pool_name)
  end
end
