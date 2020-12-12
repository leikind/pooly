defmodule Pooly.ConsumerProcessesForTesting do
  @moduledoc false

  def correct_flow do
    spawn(fn ->
      IO.puts("status")
      Pooly.status("pool-1") |> IO.inspect()

      IO.puts("checking out a worker")

      worker = Pooly.checkout("pool-1")

      IO.puts("status after a checkout")
      Pooly.status("pool-1") |> IO.inspect()

      SampleWorker.reverse_word(worker, "hello") |> IO.inspect()

      IO.puts("checking in the worker")
      Pooly.checkin("pool-1", worker)

      IO.puts("status after a check-in")
      Pooly.status("pool-1") |> IO.inspect()
    end)
  end

  def consumer_process_finishes_without_checking_in do
    task =
      Task.async(fn ->
        IO.puts("status")
        Pooly.status("pool-1") |> IO.inspect()

        IO.puts("checking out a worker")

        worker = Pooly.checkout("pool-1")

        IO.puts("status after a checkout")
        Pooly.status("pool-1") |> IO.inspect()

        SampleWorker.reverse_word(worker, "hello") |> IO.inspect()
      end)

    Task.await(task)

    IO.puts("status after a consumer process has finished without checking in the worker")
    Pooly.status("pool-1") |> IO.inspect()
  end

  def consumer_process_crashes do
    spawn(fn ->
      IO.puts("status")
      Pooly.status("pool-1") |> IO.inspect()

      IO.puts("checking out a worker")

      worker = Pooly.checkout("pool-1")

      IO.puts("status after a checkout")
      Pooly.status("pool-1") |> IO.inspect()

      SampleWorker.reverse_word(worker, "hello") |> IO.inspect()

      1 / 0

      IO.puts("checking in the worker")
      Pooly.checkin("pool-1", worker)

      IO.puts("status after a check-in")
      Pooly.status("pool-1") |> IO.inspect()
    end)

    :timer.sleep(1_000)

    IO.puts("status after a consumer process has finished without checking in the worker")
    Pooly.status("pool-1") |> IO.inspect()
  end

  def worker_crashes_in_gen_server_call do
    spawn(fn ->
      IO.puts("status")
      Pooly.status("pool-1") |> IO.inspect()

      IO.puts("checking out a worker")

      worker = Pooly.checkout("pool-1")

      IO.puts("status after a checkout")
      Pooly.status("pool-1") |> IO.inspect()

      SampleWorker.reverse_word(worker, "hello") |> IO.inspect()

      SampleWorker.crash(worker)

      IO.puts("checking in the worker")
      Pooly.checkin("pool-1", worker)

      IO.puts("status after a check-in")
      Pooly.status("pool-1") |> IO.inspect()
    end)

    :timer.sleep(1_000)

    IO.puts("status after a consumer process has crashed")
    Pooly.status("pool-1") |> IO.inspect()
  end

  def worker_crashes_by_itself do
    spawn(fn ->
      IO.puts("status")
      Pooly.status("pool-1") |> IO.inspect()

      IO.puts("checking out a worker")

      worker = Pooly.checkout("pool-1")

      IO.puts("status after a checkout")
      Pooly.status("pool-1") |> IO.inspect()

      SampleWorker.reverse_word(worker, "hello") |> IO.inspect()

      SampleWorker.crash_later(worker)

      IO.puts("status after a check-in")
      Pooly.status("pool-1") |> IO.inspect()

      :timer.sleep(1_000)

      IO.puts("status after a worker has crashed")
      Pooly.status("pool-1") |> IO.inspect()

      :timer.sleep(10_000)
    end)

    :timer.sleep(10_000)

    Pooly.status("pool-1") |> IO.inspect()
  end

  def consumer_process_waits_for_a_worker_and_gets_it_after_a_while do
    task =
      Task.async(fn ->
        IO.puts("checking out all workers")
        w1 = Pooly.checkout("pool-1")
        w2 = Pooly.checkout("pool-1")
        w3 = Pooly.checkout("pool-1")
        w4 = Pooly.checkout("pool-1")
        w5 = Pooly.checkout("pool-1")
        # all are taken
        Pooly.status("pool-1") |> IO.inspect()

        task2 =
          Task.async(fn ->
            IO.puts("requesting a worker and not getting it immediately")
            w = Pooly.checkout("pool-1")
            IO.puts("Got it: #{inspect(w)}")
            :timer.sleep(500)
            Pooly.checkin("pool-1", w)
            :timer.sleep(500)
          end)

        :timer.sleep(1_000)
        IO.puts("checking in worker 5")
        Pooly.checkin("pool-1", w5)
        Pooly.status("pool-1") |> IO.inspect()

        Pooly.checkin("pool-1", w4)
        Pooly.checkin("pool-1", w3)
        Pooly.checkin("pool-1", w2)
        Pooly.checkin("pool-1", w1)
        Task.await(task2)
      end)

    Task.await(task)
    Pooly.status("pool-1") |> IO.inspect()
  end
end
