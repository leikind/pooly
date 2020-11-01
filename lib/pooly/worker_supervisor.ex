defmodule Pooly.WorkerSupervisor do
  @moduledoc false

  use Supervisor

  def start_link({_, _, _} = mfa) do
    Supervisor.start_link(__MODULE__, mfa)
  end

  def init({m, _f, _a} = mfa) do
    children = [
      %{
        id: m,
        start: mfa,
        type: :worker,
        restart: :permanent
      }
    ]

    children
    |> Supervisor.init(
      strategy: :simple_one_for_one,
      max_restarts: 5,
      max_seconds: 5
    )
  end
end
