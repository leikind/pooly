defmodule Pooly.OnePoolSupervisor do
  @moduledoc false
  use Supervisor

  alias Pooly.{Server, WorkerSupervisor}

  def start_link(%{pool_name: pool_name} = pool_config) do
    Supervisor.start_link(__MODULE__, pool_config, name: via(pool_name))
  end

  def init(%{pool_name: pool_name} = pool_config) do
    children = [
      %{
        id: WorkerSupervisor,
        start: {WorkerSupervisor, :start_link, [pool_name]},
        type: :supervisor,
        restart: :temporary
      },
      %{
        id: Server,
        start: {Server, :start_link, [pool_config]},
        type: :worker,
        restart: :permanent
      }
    ]

    children |> Supervisor.init(strategy: :one_for_all)
  end

  defp name(pool_name), do: {pool_name, "supervisor-of-one-pool"}
  defp via(pool_name), do: {:via, Registry, {PoolRegistry, name(pool_name)}}
end
