defmodule Client do
  use Application

  alias Client.Connectivity

  def start(_type, _start_args) do
    Connectivity.connect_to_server()

    import Supervisor.Spec, warn: false

    children = [
      worker(Client.Worker, [])
    ]

    opts = [strategy: :one_for_one, name: Client.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def login(user_name, passwd) do
    GenServer.call(:some_client, {:login_user, user_name, passwd})
  end

  def logout do
    GenServer.call(:some_client, :logout_user)
  end

  def signin(user_name, passwd) do
    GenServer.call(:some_client, {:signin_user, user_name, passwd})
  end

  def delete_user(user_name, passwd) do
    GenServer.call(:some_client, {:delete_user, user_name, passwd})
  end

  def msg(to, msg) do
    GenServer.cast(:some_client, {:send_to, msg, to})
  end

  def state do
    GenServer.call(:some_client, :get_state)
  end

  def room_history(room_name) do
    GenServer.call(:some_client, {:get_room_history, room_name})
  end

  def list_rooms do
    GenServer.call(:some_client, :get_my_rooms)
  end

  def list_room_users(room_name) do
    GenServer.call(:some_client, {:list_room_users, room_name})
  end

  def add_to_room(room_name, user_name) do
    GenServer.call(:some_client, {:add_user_to_room, room_name, user_name})
  end

  def create_room(room_name) do
    GenServer.call(:some_client, {:create_room, room_name})
  end

  def help do
    IO.puts("""
    Possible functions:
    login/2
    logout/0
    signin/2
    msg/2
    state/0
    room_history/1
    list_rooms/0
    list_room_users/1
    add_to_room/2
    create_room/1
    """)
  end
end
