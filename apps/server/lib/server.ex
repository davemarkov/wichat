defmodule Server do
  use Application
  require Logger
  alias Server.Connectivity

  def start(type, _start_args) do
    import Supervisor.Spec, warn: false
    Logger.info("Enchatter Server is in #{inspect(type)} mode")

    case Connectivity.start_server() do
      {:ok, _pid} ->
        children = [
          worker(Server.Worker, []),
          supervisor(Server.Repo, [])
        ]

        opts = [strategy: :one_for_one, name: Server.Supervisor]
        Supervisor.start_link(children, opts)

      reason ->
        {:error, reason}
    end
  end

  def broadcast(msg) do
    GenServer.cast({:global, :main_server}, {:send_to_room, msg})
  end
end
