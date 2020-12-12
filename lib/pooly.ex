defmodule Pooly do
  @moduledoc false

  use Application

  @timeout 5_000

  def start(_type, _args) do
    pool_config = [mfa: {SampleWorker, :start_link, []}, size: 3, max_overflow: 2]

    children = [
      %{
        id: Pooly.Supervisor,
        start: {Pooly.Supervisor, :start_link, [pool_config]},
        type: :supervisor
      }
    ]

    opts = [strategy: :one_for_one, name: Pooly.TopSupervisor]

    children |> Supervisor.start_link(opts)
  end

  def checkout(block \\ true, timeout \\ @timeout) do
    Pooly.Server.checkout(block, timeout)
  end

  def checkin(worker_pid) do
    Pooly.Server.checkin(worker_pid)
  end

  def status do
    Pooly.Server.status()
  end
end
