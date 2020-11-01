defmodule Pooly do
  @moduledoc false

  use Application

  def start(_type, _args) do
    start_pool(
      mfa: {SampleWorker, :start_link, []},
      size: 5
    )
  end

  def start_pool(pool_config) do
    Pooly.Supervisor.start_link(pool_config)
  end

  def checkout do
    Pooly.Server.checkout()
  end

  def checkin(worker_pid) do
    Pooly.Server.checkin(worker_pid)
  end

  def status do
    Pooly.Server.status()
  end
end
