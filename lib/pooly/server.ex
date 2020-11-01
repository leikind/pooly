defmodule Pooly.Server do
  @moduledoc false

  use GenServer
  import Supervisor.Spec

  defmodule State do
    @moduledoc false
    defstruct sup: nil, worker_sup: nil, monitors: nil, size: nil, workers: nil, mfa: nil
  end

  def start_link(sup, pool_config) do
    GenServer.start_link(__MODULE__, [sup, pool_config], name: __MODULE__)
  end

  def checkout do
    GenServer.call(__MODULE__, :checkout)
  end

  def checkin(worker_pid) do
    GenServer.cast(__MODULE__, {:checkin, worker_pid})
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  #############
  # Callbacks #
  #############

  def init([sup, [mfa: mfa, size: s]]) when is_pid(sup) do
    monitors = :ets.new(:monitors, [:private])
    state = %State{sup: sup, monitors: monitors, mfa: mfa, size: s}
    send(self(), :start_worker_supervisor)
    {:ok, state}
  end

  def handle_call(:checkout, {from_pid, _ref}, %{workers: workers, monitors: monitors} = state) do
    case workers do
      [worker | rest] ->
        ref = Process.monitor(from_pid)
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | workers: rest}}

      [] ->
        {:reply, :noproc, state}
    end
  end

  def handle_call(:status, _from, %{workers: workers, monitors: monitors} = state) do
    {:reply, {length(workers), :ets.info(monitors, :size)}, state}
  end

  def handle_cast({:checkin, worker}, %{workers: workers, monitors: monitors} = state) do
    case :ets.lookup(monitors, worker) do
      [{pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        {:noreply, %{state | workers: [pid | workers]}}

      [] ->
        {:noreply, state}
    end
  end

  def handle_info(:start_worker_supervisor, %{sup: sup, mfa: mfa, size: size} = state) do
    {:ok, worker_sup} = Supervisor.start_child(sup, supervisor_spec(mfa))
    workers = prepopulate(size, worker_sup)
    {:noreply, %{state | worker_sup: worker_sup, workers: workers}}
  end

  #####################
  # Private Functions #
  #####################

  defp prepopulate(size, sup) do
    prepopulate(size, sup, [])
  end

  defp prepopulate(size, _sup, workers) when size < 1 do
    workers
  end

  defp prepopulate(size, sup, workers) do
    prepopulate(size - 1, sup, [new_worker(sup) | workers])
  end

  defp new_worker(sup) do
    {:ok, worker} = Supervisor.start_child(sup, [[]])
    worker
  end

  defp supervisor_spec({_m, _, _} = mfa) do
    # %{
    #   id: m,
    #   start: mfa,
    #   type: :supervisor,
    #   restart: :temporary
    # }

    supervisor(Pooly.WorkerSupervisor, [mfa], restart: :temporary)
  end
end
