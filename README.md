# wichat

Console based application, using Elixir for 
both client and server side, storring all users data and history in a database (Postgres), using Ecto library to interact with it.


A user can create an account and log in to view history for each chat his is a part of.
Once created an account the user can createchat rooms, add other users to it and be added to other chat rooms by member of the chat.
A chat room history is deleted once there are no users left in the room.
