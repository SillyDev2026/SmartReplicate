<img width="256" height="256" alt="image" src="https://github.com/user-attachments/assets/c2597cc3-4b52-4fe7-99df-f4fb75c72822" />

SmartReplicate is a Roblox Lua module designed to replicate player data from the client to the server safely. It ensures that all updates are validated, synchronized, and optionally visible to other clients based on a public/private sync mode. The module is built around PlayerFolder objects, which store player data in organized folders and provide change notifications, middleware support, and type enforcement.
How to Use SmartReplicate
Setup
 Place the SmartReplicate module in ReplicatedStorage along with any additional modules it requires. These modules can define custom behaviors or handle special data operations.


Creating Player Folders
 When a player joins, create a PlayerFolder for them. The folder will store all their data in a structured format. You can provide a default schema for each folder, and SmartReplicate will automatically create deep copies of this schema for each player.


Defining Data Items
 Use Define to create individual items inside a folder. Each item has a type, default value, and optional sync mode. Sync mode determines whether changes are automatically replicated to all clients or only to the client that owns the data.


Listening for Changes
 SmartReplicate allows you to attach listeners to individual data items or entire folders. Whenever an item changes, all registered listeners are automatically triggered. You can also listen for newly created folders.


Middleware
 Middleware functions let you intercept and modify values before they are saved. This is useful for enforcing rules, validating data, or applying transformations.


Updating Data
 Use Update to change the value of an item. SmartReplicate automatically checks the data type, applies middleware, triggers change events, and replicates the update to clients according to the folder’s sync mode.


Public/Private Sync
 Each folder can be public or private. Public folders replicate changes to all clients, whereas private folders replicate changes only to the owning player. You can change sync mode dynamically at any time.


Cleaning Up
 When a player leaves, SmartReplicate automatically removes their folder and notifies clients. You can also manually remove folders if needed.


Integration with Modules
 Additional modules can be stored inside the Modules folder and invoked through SmartReplicate. These modules can define extra behaviors, such as custom data processing, server-side logic, or special events.


SmartReplicate is designed for flexibility, security, and ease of use. It abstracts the complexity of client-server replication, making it safe and reliable for multiplayer Roblox games.



