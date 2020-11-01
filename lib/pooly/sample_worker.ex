defmodule SampleWorker do
  @moduledoc false

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def reverse_word(pid, word) do
    GenServer.call(pid, {:reverse_word, word})
  end

  def crash(pid) do
    GenServer.call(pid, :crash)
  end

  def crash_later(pid) do
    GenServer.call(pid, :crash_later)
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call(:crash, _from, state) do
    _a = 1 / 0
    {:reply, :ok, state}
  end

  def handle_call(:crash_later, _from, state) do
    send(self(), :crash_now)
    {:reply, :ok, state}
  end

  def handle_call({:reverse_word, word}, _from, state) do
    {:reply, String.reverse(word), state}
  end

  def handle_info(:crash_now, state) do
    1 / 0

    {:noreply, state}
  end
end
