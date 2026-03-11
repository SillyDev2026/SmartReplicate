# DataStore Builder & SmartReplicate

DataStore Builder is a Roblox Studio plugin for creating and managing DataStore modules with folders, keys, and typed values. It provides a GUI for editing, searching, saving, and exporting structured data, and integrates with the SmartReplicate module for safe client-server data replication.

---

## 📌 Plugin Overview

- Create and manage DataStore modules.
- Organize data in structured folders and typed keys.
- Save, update, and replicate data safely with SmartReplicate.
- Search, filter, and edit data directly from the plugin interface.

---

## 🖼️ Screenshots

### Plugin Icon
![Plugin Icon](https://github.com/user-attachments/assets/c2597cc3-4b52-4fe7-99df-f4fb75c72822)

### Main Interface
![Main Interface](https://github.com/user-attachments/assets/ab6e0d6d-2799-4cec-a916-3fed41235cd7)

### Types & Search Panel
![Types & Search](https://github.com/user-attachments/assets/0cf4c717-2b26-4cac-8ae7-1b9305b8be2e)
![Types & Search](https://github.com/user-attachments/assets/8424e3fd-1327-4094-9a13-0489cedead16)
![Types & Search](https://github.com/user-attachments/assets/dd9564e4-14c6-49d2-86aa-8969ba89222b)
![Types & Search](https://github.com/user-attachments/assets/a036b6c6-b8d8-4ef9-bfa6-c4ebd168ae51)
![Types & Search](https://github.com/user-attachments/assets/41581f36-3e78-4e2e-8386-44891c6b85a7)

### Save State
![Save State](https://github.com/user-attachments/assets/2483a8ae-b30a-4a02-be2f-d6b546b9bd47)

### Create/Update Modules
![Create/Update Modules](https://github.com/user-attachments/assets/207081fe-2d92-44c9-8ed2-3f66ee224e0b)

### Empty Folder View
![Empty Folder](https://github.com/user-attachments/assets/a3fbc5bc-f6c5-4984-8132-0aad483992ca)

### Rename Folders
![Rename Folder](https://github.com/user-attachments/assets/1fa4b5b2-2480-4f53-8d02-7d4757f80be6)

### Type Overview & Search Suggestions
![Type Overview](https://github.com/user-attachments/assets/843f4998-3e9e-4485-bc3c-ea25275ca0f1)

---

## 🛒 Plugin Store
[Roblox Store Link](https://create.roblox.com/store/asset/106198281373990/DataStoreService)

---

## 💬 Support
For errors, feedback, or feature suggestions, join the Discord server:  
[Discord Invite](https://discord.gg/xtEMCYmuKk)

---

## SmartReplicate Module

SmartReplicate is a Roblox Lua module designed to safely replicate player data from the client to the server. It validates, synchronizes, and optionally shares data with other clients. Data is organized using `PlayerFolder` objects with middleware, type enforcement, and event notifications.

<details>
<summary>How to Use SmartReplicate</summary>

### 1. Setup
Place the SmartReplicate module in `ServerScriptService` along with any additional modules for custom behaviors or special data operations.

### 2. Creating Player Folders
When a player joins, create a `PlayerFolder`. Each folder stores all player data in a structured format. SmartReplicate auto-copies a default schema for every player.

### 3. Defining Data Items
Use `Define` to create items inside a folder. Each item has:
- Type
- Default value
- Optional sync mode (public/private)

Public folders replicate to all clients, private folders replicate only to the owner.

### 4. Listening for Changes
Attach listeners to individual items or entire folders. Listeners trigger automatically on changes. You can also monitor newly created folders.

### 5. Middleware
Middleware functions intercept and modify values before saving. Useful for validation, rule enforcement, or transformations.

### 6. Updating Data
Use `Update` to change item values. SmartReplicate:
- Checks type
- Applies middleware
- Triggers events
- Replicates updates according to sync mode

### 7. Public/Private Sync
- **Public:** Replicates changes to all clients.
- **Private:** Replicates changes to the owning player only.  
Sync mode can be changed dynamically.

### 8. Cleaning Up
When a player leaves, their folder is removed, and clients are notified. Manual folder removal is also supported.

### 9. Integration with Modules
Additional modules can define extra behaviors, custom data processing, server-side logic, or special events.

SmartReplicate abstracts client-server replication, making multiplayer data handling safe, secure, and reliable.

</details>
