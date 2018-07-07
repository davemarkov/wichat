defmodule Server.Worker do
  use GenServer

  alias Server.{Users, Rooms, Messages, Repo}

  require Ecto.Query

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: {:global, :main_server})
  end

  def init(_) do
    {:ok, %{user_info: %{}, references: %{}}}
    # {:ok, %{}}
  end

  def list do
    GenServer.call({:global, :main_server}, :list_logged_users)
  end

  def state do
    GenServer.call({:global, :main_server}, :state)
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:signin_user, user_name, passwd}, _from, state) do
    reply = insert_user_db(user_name, passwd)
    {:reply, reply, state}
  end

  def handle_call({:delete_user, user_name, passwd}, _from, %{user_info: info} = state) do
    case Map.has_key?(info, user_name) do
      true ->
        {:reply, :user_logged_in, state}

      false ->
        reply = delete_user_db(user_name, passwd)
        {:reply, reply, state}
    end
  end

  def handle_call({:login_user, user_name, passwd}, {from, _}, %{user_info: info} = state) do
    case Map.has_key?(info, user_name) do
      true ->
        {:reply, :taken, state}

      false ->
        case Repo.get_by(Users, name: user_name) do
          nil ->
            {:reply, :no_user_data, state}

          %{passwd: ^passwd} ->
            ref = Process.monitor(from)

            new_state =
              put_in(state, [:user_info, user_name], {ref, node(from)})
              |> put_in([:references, ref], user_name)

            # new_state = Map.put(state, user_name, node(from))

            {:reply, :logged_in, new_state}

          _ ->
            {:reply, :invalid_passwd, state}
        end

        ####### returns user's chat room
    end
  end

  def handle_call({:add_to_room, room_name, user_name}, _from, state) do
    reply = add_user_to_room_db(room_name, user_name)
    {:reply, reply, state}
  end

  def handle_call({:create_room, room_name, user_name}, _from, state) do
    reply = insert_room_db(room_name, user_name)
    {:reply, reply, state}
  end

  def handle_call({:get_rooms, user_name}, _from, state) do
    reply =
      get_user_rooms_db(user_name)
      |> Enum.map(fn %Server.Rooms{room_name: name} -> name end)

    {:reply, reply, state}
  end

  def handle_call({:get_room_users, room_name}, _from, state) do
    reply =
      get_room_users_db(room_name)
      |> Enum.map(fn %Server.Users{name: name} -> name end)

    {:reply, reply, state}
  end

  def handle_call({:get_room_msg, room_name, user_name}, _from, %{user_info: info} = state) do
    case Map.has_key?(info, user_name) do
      true ->
        reply = get_history_db(room_name, user_name)
        {:reply, reply, state}

      false ->
        {:reply, :not_loggedin, state}
    end
  end

  def handle_call({:leave_room, room_name, user_name, passwd}, _from, state) do
    case Repo.get_by(Users, name: user_name) do
      nil ->
        {:reply, :wrong_credentials, state}

      %Users{passwd: ^passwd} ->
        remove_user_from_room_db(room_name, user_name)
    end
  end

  def handle_call(:list_logged_users, _from, %{user_info: info} = state) do
    {:reply, Map.keys(info), state}
  end

  def handle_cast({:logout_user, user_name}, %{user_info: info, references: references} = state) do
    {ref, _} = Map.get(info, user_name)
    Process.demonitor(ref)

    {:noreply,
     %{state | user_info: Map.delete(info, user_name), references: Map.delete(references, ref)}}
  end

  def handle_cast({:send_to_room, msg, room, from}, %{user_info: info} = state) do
    IO.puts("logmsg")

    case Repo.get_by(Rooms, room_name: room) do
      nil ->
        IO.puts("Invalid room. Cannot send.")

      _ ->
        insert_room_message_db(room, msg, from)
        IO.puts("here")

        get_room_users_db(room)
        |> Enum.map(fn %Server.Users{name: name} -> name end)
        |> Enum.filter(&Map.has_key?(info, &1))
        |> List.delete(from)
        |> Enum.each(&send_message(&1, msg, from, room, info))
    end

    {:noreply, state}
  end

  def send_message(user, msg, from, room, %{user_info: info}) do
    {_, receive_addr} = Map.get(info, user)
    GenServer.cast({:some_client, receive_addr}, {:receive_msg, msg, from, room})
  end

  def handle_info({:DOWN, ref, _, _, _}, state) do
    case pop_in(state, [:references, ref]) do
      {nil, _} ->
        {:noreply, state}

      {user_name, new_state} ->
        IO.puts("User #{user_name} disconected.")
        {_, new_state} = pop_in(new_state, [:user_info, user_name])
        {:noreply, new_state}
    end
  end

  def insert_user_db(name, passwd) do
    case Repo.get_by(Users, name: name) do
      nil ->
        Repo.insert(%Users{name: name, passwd: passwd})
        :ok

      _ ->
        :taken
    end
  end

  def delete_user_db(name, passwd) do
    case Repo.get_by(Users, name: name) do
      %{passwd: ^passwd} = user_data ->
        Server.Repo.delete(user_data)
        :deleted

      nil ->
        :invalid_name

      _ ->
        :invalid_passwd
    end
  end

  def insert_room_db(room_name, user_name) do
    case Repo.get_by(Server.Rooms, room_name: room_name) do
      nil ->
        room = Repo.insert!(%Server.Rooms{room_name: room_name})
        user = Repo.get_by(Users, name: user_name)

        room
        |> Repo.preload(:users)
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_assoc(:users, [user])
        |> Repo.update!()

        :ok

      _ ->
        :taken
    end
  end

  def add_user_to_room_db(room_name, user_name) do
    users = get_room_users_db(room_name)

    # case check_users_db(users, user_name) do
    # nil ->
    user_to_add = Repo.get_by(Users, name: user_name)

    Repo.get_by(Rooms, room_name: room_name)
    |> Repo.preload(:users)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:users, [user_to_add | users])
    |> Repo.update!()

    :ok

    # %Server.Users{name: ^user_name} ->
    # :user_exists
    # end
  end

  def remove_user_from_room_db(room_name, user_name) do
    room = Repo.get_by(Rooms, room_name: room_name)

    users =
      Repo.all(
        Ecto.Query.from(
          u in Ecto.assoc(room, :users),
          where: u.name != ^user_name
        )
      )

    room
    |> Repo.preload(:users)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:users, users)
    |> Repo.update!()

    :ok
  end

  def insert_room_message_db(room_name, message, from) do
    case Repo.get_by(Rooms, room_name: room_name) do
      nil ->
        :error

      room ->
        Ecto.build_assoc(room, :messages, %Messages{messages: message, from: from})
        |> Server.Repo.insert!()
    end
  end

  def check_users_db(users, user_name) do
    IO.puts("second")
    Repo.get_by(users, name: user_name)
  end

  def get_room_users_db(room_name) do
    case Repo.get_by(Rooms, room_name: room_name) do
      nil ->
        []

      room ->
        Repo.all(Ecto.assoc(room, :users))
    end
  end

  def get_user_rooms_db(user_name) do
    case Repo.get_by(Users, name: user_name) do
      nil ->
        []

      user ->
        Repo.all(Ecto.assoc(user, :rooms))
    end
  end

  def get_history_db(room_name, user_name) do
    case Server.Rooms
         |> Repo.get_by(room_name: room_name)
         |> Ecto.assoc(:users)
         |> Repo.get_by(name: user_name) do
      nil ->
        {:error, :not_member}

      _ ->
        Repo.all(
          Ecto.Query.from(
            m in Server.Messages,
            join: r in Server.Rooms,
            on: r.id == m.rooms_id,
            where: r.room_name == ^room_name,
            select: %{msg: m.messages, date: m.inserted_at, from: m.from}
          )
        )
    end
  end
end
