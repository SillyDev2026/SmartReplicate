<img width="256" height="256" alt="image" src="https://github.com/user-attachments/assets/c2597cc3-4b52-4fe7-99df-f4fb75c72822" />

<img width="1126" height="749" alt="image" src="https://github.com/user-attachments/assets/ab6e0d6d-2799-4cec-a916-3fed41235cd7" />

<img width="1133" height="754" alt="image" src="https://github.com/user-attachments/assets/0cf4c717-2b26-4cac-8ae7-1b9305b8be2e" />

<img width="1132" height="759" alt="image" src="https://github.com/user-attachments/assets/8424e3fd-1327-4094-9a13-0489cedead16" />

<img width="1133" height="755" alt="image" src="https://github.com/user-attachments/assets/dd9564e4-14c6-49d2-86aa-8969ba89222b" />

<img width="1126" height="755" alt="image" src="https://github.com/user-attachments/assets/a036b6c6-b8d8-4ef9-bfa6-c4ebd168ae51" />

<img width="1129" height="751" alt="image" src="https://github.com/user-attachments/assets/41581f36-3e78-4e2e-8386-44891c6b85a7" />

<img width="406" height="72" alt="image" src="https://github.com/user-attachments/assets/2483a8ae-b30a-4a02-be2f-d6b546b9bd47" />
this part is to save state

<img width="335" height="87" alt="image" src="https://github.com/user-attachments/assets/207081fe-2d92-44c9-8ed2-3f66ee224e0b" />
this part is to either create ur modules to SmartReplicate or update and create folder and module

<img width="1128" height="756" alt="image" src="https://github.com/user-attachments/assets/a3fbc5bc-f6c5-4984-8132-0aad483992ca" />
if folder has nothing this is what it will look like

<img width="397" height="276" alt="image" src="https://github.com/user-attachments/assets/1fa4b5b2-2480-4f53-8d02-7d4757f80be6" />
left button click u can edit the folders name

<img width="1131" height="754" alt="image" src="https://github.com/user-attachments/assets/843f4998-3e9e-4485-bc3c-ea25275ca0f1" />
as u can see it shows u what there is for types and the searches

https://create.roblox.com/store/asset/106198281373990/DataStoreService

if any errors or suggestions join the server and ill be glad to improve the plugin
https://discord.gg/xtEMCYmuKk

SmartReplicate is a Roblox Lua module designed to replicate player data from the client to the server safely. It ensures that all updates are validated, synchronized, and optionally visible to other clients based on a public/private sync mode. The module is built around PlayerFolder objects, which store player data in organized folders and provide change notifications, middleware support, and type enforcement.
How to Use SmartReplicate
Setup
 Place the SmartReplicate module in ServerScriptService along with any additional modules it requires. These modules can define custom behaviors or handle special data operations.


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



