defmodule Client.Worker do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: :some_client)
  end

  def init(_) do
    {:ok, %{name: nil, rooms: nil, ref: nil}}
  end

  def get_state, do: GenServer.call(:some_client, :get_state)

  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  def handle_call({:signin_user, user_name, passwd}, _from, state) do
    reply =
      case :global.whereis_name(:main_server) do
        :undefined ->
          :server_unavaible

        _ ->
          GenServer.call({:global, :main_server}, {:signin_user, user_name, passwd})
      end

    {:reply, reply, state}
  end

  def handle_call({:delete_user, user_name, passwd}, _from, %{name: nil} = state) do
    case GenServer.call({:global, :main_server}, {:delete_user, user_name, passwd}) do
      :deleted ->
        {:reply, :ok, %{name: nil, rooms: nil, ref: nil}}

      reply ->
        {:reply, reply, state}
    end
  end

  def handle_call({:delete_user, _, _}, _from, state) do
    {:reply, :user_is_loggedin, state}
  end

  def handle_call({:login_user, user_name, passwd}, _from, %{name: nil}) do
    responce =
      case :global.whereis_name(:main_server) do
        :undefined ->
          :server_unavaible

        pid ->
          case server_alive?(pid) do
            true ->
              GenServer.call({:global, :main_server}, {:login_user, user_name, passwd})

            false ->
              :sever_unavaible
          end
      end

    case responce do
      :logged_in ->
        ref = Process.monitor(:global.whereis_name(:main_server))
        IO.puts("Login successful.")
        {:reply, :logged_in, %{name: user_name, rooms: [], ref: ref}}

      :taken ->
        IO.puts("Someone alredy logged in with that user name.")
        IO.puts("Try again.")
        {:reply, :taken, %{name: nil, rooms: nil, ref: nil}}

      _ ->
        {:reply, responce, %{name: nil, rooms: nil, ref: nil}}
    end
  end

  def handle_call({:login_user, _user_name, _passwd}, _from, state) do
    IO.puts("user alredy logged in")
    {:reply, :alredy_loggedin, state}
  end

  def handle_call(:logout_user, _from, %{name: nil} = state) do
    IO.puts("No user logged in.")
    {:reply, :no_user, state}
  end

  def handle_call(:logout_user, _from, %{name: user_name, ref: ref}) do
    reply = GenServer.cast({:global, :main_server}, {:logout_user, user_name})
    Process.demonitor(ref)
    {:reply, reply, %{name: nil, rooms: nil, ref: nil}}
  end

  ## def find_user

  # get tests
  def handle_call({:get_room_history, _}, _from, %{name: nil} = state) do
    {:reply, :no_user_loggedin, state}
  end

  def handle_call({:get_room_history, room_name}, _from, %{name: user_name} = state) do
    reply = GenServer.call({:global, :main_server}, {:get_room_msg, room_name, user_name})
    {:reply, reply, state}
  end

  def handle_call(:get_my_rooms, _from, %{name: nil} = state) do
    {:reply, :no_user_loggedin, state}
  end

  def handle_call(:get_my_rooms, _from, %{name: user_name} = state) do
    reply = GenServer.call({:global, :main_server}, {:get_rooms, user_name})
    {:reply, reply, state}
  end

  def handle_call({:list_room_users, _}, _from, %{name: nil} = state) do
    {:reply, :no_user_loggedin, state}
  end

  def handle_call({:list_room_users, room_name}, _from, state) do
    reply = GenServer.call({:global, :main_server}, {:get_room_users, room_name})
    {:reply, reply, state}
  end

  def handle_call({:add_user_to_room, _, _}, _from, %{name: nil} = state) do
    {:reply, :no_user_loggedin, state}
  end

  def handle_call({:add_user_to_room, room_name, user_name}, _from, state) do
    reply = GenServer.call({:global, :main_server}, {:add_to_room, room_name, user_name})
    {:reply, reply, state}
  end

  def handle_call({:create_room, _}, _from, %{name: nil} = state) do
    {:reply, :no_user_loggedin, state}
  end

  def handle_call({:create_room, room_name}, _from, %{name: user_name} = state) do
    reply = GenServer.call({:global, :main_server}, {:create_room, room_name, user_name})
    {:reply, reply, state}
  end

  # def join_room
  def handle_cast({:send_to, _msg, _to}, %{name: nil} = state) do
    IO.puts("Can't send message.")
    IO.puts("No user logged in.")
    {:noreply, state}
  end

  def handle_cast({:send_to, msg, to}, %{name: from} = state) do
    GenServer.cast({:global, :main_server}, {:send_to_room, msg, to, from})
    {:noreply, state}
  end

  def handle_cast({:receive_msg, msg, from, room}, state) do
    IO.puts("\nRoom:#{room},From:#{from}")
    IO.puts("At:#{DateTime.utc_now() |> DateTime.to_string()}")
    IO.puts("#{String.trim(msg)}\n")
    IO.write("iex(#{Node.self()})> ")

    {:noreply, state}
  end

  def handle_info({:DOWN, _, _, _, _}, %{ref: nil} = state), do: {:noreply, state}

  def handle_info({:DOWN, _, _, _, _}, _state) do
    IO.puts("Disconnected. Server down.")
    IO.puts("User logged out.")
    Process.sleep(1_000)

    case server_alive?(:global.whereis_name(:main_server)) do
      true ->
        IO.puts("Connected.")
        {:noreply, %{name: nil, rooms: nil, ref: nil}}

      false ->
        try_reconnect()
        {:noreply, %{name: nil, rooms: nil, ref: nil}}
    end
  end

  def try_reconnect do
    case Client.Connectivity.connect_to_server() do
      true ->
        IO.puts("Connected.")
        :ok

      _reply ->
        # IO.puts(reply)
        IO.puts("REACHING SERVER...")
        Process.sleep(1_500)
        try_reconnect()
    end
  end

  def server_alive?(pid) do
    case Node.alive?() do
      true ->
        {replys, _} = :rpc.multicall(Node.list(), Process, :alive?, [pid])

        replys
        |> Enum.any?(&(&1 == true))

      false ->
        Process.alive?(pid)
    end
  end
end
