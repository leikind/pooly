defmodule Pooly.Server do
  @moduledoc false

  use GenServer
  require Logger

  defmodule State do
    @moduledoc false
    defstruct [
      :worker_sup,
      :monitors,
      :size,
      :workers,
      :mfa,
      :max_overflow,
      :waiting,
      :pool_name,
      overflow: 0
    ]
  end

  defp name(pool_name), do: {pool_name, "server"}
  defp via(pool_name), do: {:via, Registry, {PoolRegistry, name(pool_name)}}

  def start_link(%{pool_name: pool_name} = pool_config) do
    GenServer.start_link(__MODULE__, pool_config, name: via(pool_name))
  end

  def checkout(pool_name, block, timeout) do
    GenServer.call(via(pool_name), {:checkout, block}, timeout)
  end

  def checkin(pool_name, worker_pid) do
    GenServer.cast(via(pool_name), {:checkin, worker_pid})
  end

  def status(pool_name) do
    GenServer.call(via(pool_name), :status)
  end

  #############
  # Callbacks #
  #############

  def init(%{mfa: mfa, size: s, max_overflow: max_overflow, pool_name: pool_name}) do
    Process.flag(:trap_exit, true)
    monitors = :ets.new(:monitors, [:private])

    state = %State{
      monitors: monitors,
      mfa: mfa,
      size: s,
      max_overflow: max_overflow,
      waiting: :queue.new(),
      pool_name: pool_name
    }

    send(self(), :start_workers)
    {:ok, state}
  end

  def handle_call(
        {:checkout, block},
        {from_pid, _ref} = from,
        %{
          workers: workers,
          monitors: monitors,
          max_overflow: max_overflow,
          overflow: overflow,
          waiting: waiting,
          worker_sup: worker_sup,
          mfa: mfa
        } = state
      ) do
    case workers do
      [worker | rest] ->
        ref = Process.monitor(from_pid)
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | workers: rest}}

      [] when max_overflow > 0 and overflow < max_overflow ->
        worker = new_worker(worker_sup, mfa)
        ref = Process.monitor(from_pid)
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | overflow: overflow + 1}}

      [] when block == true ->
        ref = Process.monitor(from_pid)
        waiting = :queue.in({from, ref}, waiting)
        {:noreply, %{state | waiting: waiting}, :infinity}

      [] ->
        {:reply, :noproc, state}
    end
  end

  def handle_call(
        :status,
        _from,
        %{workers: workers, monitors: monitors, overflow: overflow, max_overflow: max_overflow} =
          state
      ) do
    available_workers = length(workers)

    state_name =
      cond do
        available_workers > 0 -> :ready
        overflow < max_overflow -> :overflow
        overflow == max_overflow -> :full
      end

    report = [
      available_workers: available_workers,
      checked_out_workers: :ets.info(monitors, :size),
      state_name: state_name
    ]

    {:reply, report, state}
  end

  def handle_cast({:checkin, worker}, %{monitors: monitors} = state) do
    case :ets.lookup(monitors, worker) do
      [{worker_pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, worker_pid)
        new_state = handle_checkin(worker_pid, state)
        {:noreply, new_state}

      [] ->
        {:noreply, state}
    end
  end

  def handle_info(:start_workers, %{mfa: mfa, size: size, pool_name: pool_name} = state) do
    [{worker_sup, _} | _] = Registry.lookup(PoolRegistry, Pooly.WorkerSupervisor.name(pool_name))

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

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:EXIT, pid, _reason}, %{monitors: monitors} = state) do
    case :ets.lookup(monitors, pid) do
      [{worker_pid, ref}] ->
        Logger.info("worker crashed! #{inspect(worker_pid)}")
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        new_state = handle_worker_exit(state)

        {:noreply, new_state}

      [[]] ->
        {:noreply, state}
    end
  end

  #####################
  # Private Functions #
  #####################

  def handle_worker_exit(
        %{
          worker_sup: worker_sup,
          mfa: mfa,
          workers: workers,
          overflow: overflow,
          monitors: monitors,
          waiting: waiting
        } = state
      ) do
    case :queue.out(waiting) do
      {{:value, {from, ref}}, left} ->
        replacement_worker = new_worker(worker_sup, mfa)
        true = :ets.insert(monitors, {replacement_worker, ref})
        GenServer.reply(from, replacement_worker)
        %{state | waiting: left}

      {:empty, empty} when overflow > 0 ->
        %{state | overflow: overflow - 1, waiting: empty}

      {:empty, empty} ->
        replacement_worker = new_worker(worker_sup, mfa)
        %{state | workers: [replacement_worker | workers], waiting: empty}
    end
  end

  def handle_checkin(
        worker_pid,
        %{
          workers: workers,
          overflow: overflow,
          worker_sup: worker_sup,
          waiting: waiting,
          monitors: monitors
        } = state
      ) do
    case :queue.out(waiting) do
      {{:value, {from, ref}}, left} ->
        # hand over the worker to a waiting consumer
        true = :ets.insert(monitors, {worker_pid, ref})
        GenServer.reply(from, worker_pid)
        %{state | waiting: left}

      {:empty, empty} when overflow > 0 ->
        true = Process.unlink(worker_pid)
        DynamicSupervisor.terminate_child(worker_sup, worker_pid)
        # `waiting: empty` can be dropped I think
        %{state | waiting: empty, overflow: overflow - 1}

      {:empty, empty} ->
        %{state | waiting: empty, workers: [worker_pid | workers]}
    end
  end

  defp prepopulate(size, worker_sup, mfa) do
    1..size
    |> Enum.map(fn _ ->
      new_worker(worker_sup, mfa)
    end)
  end

  defp new_worker(worker_sup, mfa) do
    {:ok, worker} = Pooly.WorkerSupervisor.start_child(worker_sup, mfa)
    Process.link(worker)
    worker
  end
end
