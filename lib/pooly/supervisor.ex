defmodule Pooly.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(%{pool_name: pool_name} = pool_config) do
    Supervisor.start_link(__MODULE__, pool_config, name: via(pool_name))
  end

  def init(%{pool_name: pool_name} = pool_config) do
    children = [
      %{
        id: Pooly.WorkerSupervisor,
        start: {Pooly.WorkerSupervisor, :start_link, [pool_name]},
        type: :supervisor,
        restart: :temporary
      },
      %{
        id: Pooly.Server,
        start: {Pooly.Server, :start_link, [pool_config]},
        type: :worker,
        restart: :permanent
      }
    ]

    children |> Supervisor.init(strategy: :one_for_all)
  end

  defp name(pool_name), do: {pool_name, "supervisor-of-one-pool"}
  defp via(pool_name), do: {:via, Registry, {PoolRegistry, name(pool_name)}}
end
