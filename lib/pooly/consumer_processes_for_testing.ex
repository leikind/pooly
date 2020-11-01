defmodule Pooly.ConsumerProcessesForTesting do
  @moduledoc false

  def correct_flow do
    spawn(fn ->
      IO.puts("status")
      Pooly.Server.status() |> IO.inspect()

      IO.puts("checking out a worker")

      worker = Pooly.Server.checkout()

      IO.puts("status after a checkout")
      Pooly.Server.status() |> IO.inspect()

      SampleWorker.reverse_word(worker, "hello") |> IO.inspect()

      IO.puts("checking in the worker")
      Pooly.Server.checkin(worker)

      IO.puts("status after a check-in")
      Pooly.Server.status() |> IO.inspect()
    end)
  end

  def consumer_process_finishes_without_checking_in do
    task =
      Task.async(fn ->
        IO.puts("status")
        Pooly.Server.status() |> IO.inspect()

        IO.puts("checking out a worker")

        worker = Pooly.Server.checkout()

        IO.puts("status after a checkout")
        Pooly.Server.status() |> IO.inspect()

        SampleWorker.reverse_word(worker, "hello") |> IO.inspect()
      end)

    Task.await(task)

    IO.puts("status after a consumer process has finished without checking in the worker")
    Pooly.Server.status() |> IO.inspect()
  end

  def consumer_process_crashes do
    spawn(fn ->
      IO.puts("status")
      Pooly.Server.status() |> IO.inspect()

      IO.puts("checking out a worker")

      worker = Pooly.Server.checkout()

      IO.puts("status after a checkout")
      Pooly.Server.status() |> IO.inspect()

      SampleWorker.reverse_word(worker, "hello") |> IO.inspect()

      1 / 0

      IO.puts("checking in the worker")
      Pooly.Server.checkin(worker)

      IO.puts("status after a check-in")
      Pooly.Server.status() |> IO.inspect()
    end)

    :timer.sleep(1_000)

    IO.puts("status after a consumer process has finished without checking in the worker")
    Pooly.Server.status() |> IO.inspect()
  end
end
