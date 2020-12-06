defmodule Pooly do
  @moduledoc false

  use Application

  @timeout 5_000

  def start(_type, _args) do
    start_pool(
      mfa: {SampleWorker, :start_link, []},
      size: 3,
      max_overflow: 2
    )
  end

  def start_pool(pool_config) do
    Pooly.Supervisor.start_link(pool_config)
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
