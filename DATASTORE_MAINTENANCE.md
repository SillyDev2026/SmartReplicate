# SmartReplicate DataStore safety regression notes

This branch repairs issues in the legacy `Module/DataStore.lua` wrapper and `Module/PlayersDataStore.lua` backend without changing their exported method names.

## Fixed behavior

- The backend's `AcquireLock()` now checks the **returned owner** from `UpdateAsync`. A successful request that returned `nil` due to another session is **not** a lock acquisition.
- The backend `UpdateAsync()` waits until the actual DataStore write completes instead of returning success merely because it enqueued an operation. That queue was a source of false success reports.
- Retries have a finite count (6) and capped exponential delays instead of an unbounded outer loop.
- The wrapper no longer requires a nonexistent `PlayersData` sibling.
- A failure to load saved data no longer silently creates a new empty profile that could overwrite existing progress.
- Save operations reject an unavailable lock or missing session. Wrapper `UpdateAsync` now propagates the backend result correctly.
- `BindOnSet()` and `BindOnUpdate()` operate on the **server**, build each player key independently, and wait for parallel saves up to 24 seconds rather than a single fixed two-second delay.
- `DataStore.lua` does not create a replication folder if loading failed.

## Remaining architectural limitations

This version uses separate lock keys inside an ordinary Roblox DataStore. Locks are short-lived (30 seconds by default) and are released after individual operations rather than owned for the entire player session; **this is not equivalent to a fully durable session-locking profile system**. A production replacement requires an explicit lock lifecycle, leased refreshes, retryable release and conflict-resolution tests. Do not use this code to overwrite important production player profiles until migration and Studio integration tests pass.

The repository expects specific Studio hierarchy names, including a server `DataStore` Script with child modules and `ReplicatedStorage.NetworkHandler` plus an `Events` module from your framework. The GitHub source filenames `VituralReplicate.lua` and `Module/` are not identical to all `require` paths in the sample scripts. Match the actual placed ModuleScript names to each `require` when installing. The external transport package is not included.

## Studio verification

Run `tests/DataStoreLockRegression.server.lua` beside a folder named `Module` containing `PlayersDataStore`. The test uses a mocked DataStore `UpdateAsync` and **does not persist any player data**. Separately, in a disposable testing experience with Studio API services enabled, verify the actual round trip and locked/retrying write behavior. Always use a different DataStore name from live player data.

Check both modules with Script Analysis. Existing dynamic-table APIs are not yet entirely `--!strict`, and this PR does not assert complete static type soundness or a measured runtime speedup.
