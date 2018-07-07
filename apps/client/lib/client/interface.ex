defmodule Client.Interface do

  def listen_commands do
    case IO.gets("> ")
    |> handle_command do
      :ok ->
        listen_commands()
      :exit -> :ok
    end
  end

  def handle_command("login\n") do
    user_name = IO.gets("user name: ")
    passwd = IO.gets("passsword: ")
    GenServer.call(:some_client, {:login_user, user_name, passwd})
    :ok
  end

  def handle_command("logout\n") do
    GenServer.call(:some_client, :logout_user)
    :ok
  end

  def handle_command("signin\n") do
    user_name = IO.gets("user name: ")
    passwd = IO.gets("passsword: ")
    GenServer.call(:some_client, {:signin_user, user_name, passwd})
    :ok
  end

  def handle_command("msg\n") do
    to = IO.gets("send message to: ")
    msg = IO.gets("enter message: ")
    GenServer.cast(:some_client, {:send_to, msg, to})
    :ok
  end

  def handle_command("exit\n"), do: :exit

  def handle_command(_) do
    IO.puts("Invalid command")
    :ok
  end
end
