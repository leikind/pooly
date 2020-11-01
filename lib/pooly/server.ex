defmodule Pooly.Server do
  @moduledoc false

  use GenServer
  import Supervisor.Spec
  require Logger

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
    {:ok, worker_sup} = Supervisor.start_child(sup, supervisor_spec())
    workers = prepopulate(size, worker_sup, mfa)

    {:noreply, %{state | worker_sup: worker_sup, workers: workers}}
  end

  def handle_info({:DOWN, ref, _, _, _}, %{monitors: monitors, workers: workers} = state) do
    Logger.info("consumer process finished")

    case :ets.match(monitors, {:"$1", ref}) do
      [[pid]] ->
        Logger.info("taking the worker back from the finished consumer process")
        true = :ets.delete(monitors, pid)
        new_state = %{state | workers: [pid | workers]}
        {:noreply, new_state}

      [[]] ->
        {:noreply, state}
    end
  end

  #####################
  # Private Functions #
  #####################

  defp prepopulate(size, worker_sup, mfa) do
    1..size
    |> Enum.map(fn _ ->
      new_worker(worker_sup, mfa)
    end)
  end

  defp new_worker(worker_sup, mfa) do
    {:ok, worker} = Pooly.WorkerSupervisor.start_child(worker_sup, mfa)
    worker
  end

  defp supervisor_spec do
    # %{
    #   id: m,
    #   start: mfa,
    #   type: :supervisor,
    #   restart: :temporary
    # }

    supervisor(Pooly.WorkerSupervisor, [], restart: :temporary)
  end
end
