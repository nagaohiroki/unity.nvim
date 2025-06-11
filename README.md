# unity.nvim

This is a Neovim plugin for Unity

- Unity Play/Stop/Refresh with Neovim commands.
- Debug Unity from Neovim. (Please check the license of the package before using it.)
   - [vstuc](https://marketplace.visualstudio.com/items?itemName=VisualStudioToolsForUnity.vstuc)


## Requrements

- Neovim >= 0.10.0
- [NeovimForUnity](https://github.com/nagaohiroki/NeovimForUnity) (Unity Package)
- .NET SDK installed and `dotnet` command available(for vsutc debugger)

## Installation

* [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'nagaohiroki/unity.nvim',
  opts = {}
}
```

| Command |   |
| ------------- | -------------- |
|  URefresh | Refresh Unity |
|  UPlay | Play Unity |
|  UStop | Stop Playing Unity |
|  UPause | Pause Unity |
|  Unpause | Unpause Unity |
|  ShowUnityProcess | Show Debug Target Info |
|  UnityDebuggerInstall | Install Debugger  \*1 |
|  UnityDebuggerUninstall| Uninstall Debugger  |

\*1 Installed debugger path.
- **Linux** or **MacOS**: `~/.local/share/nvim/unity-debugger`
- **Windows**: `%LOCALAPPDATA%\nvim-data\unity-debugger`

## Default Configuration

```lua
{
  'nagaohiroki/unity.nvim',
  opts = {
    discover_time       = 2000,
    install_path        = vim.fs.joinpath(vim.fn.stdpath('data'), 'unity-debugger', 'extensions'),
    install_path_vscode = vim.fs.joinpath(vim.env.HOME, '.vscode', 'extensions'),
    debugger            = 'vstuc',
    debuggers           =
    {
      vstuc =
      {
        publisher = 'VisualStudioToolsForUnity',
        extension = 'vstuc',
        version   = '1.1.2',
      },
    },
  }
}
```
