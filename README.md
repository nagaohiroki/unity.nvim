# unity.nvim

This is a Neovim plugin for Unity

- Unity Play/Stop/Refresh with Neovim commands.
- Configuration options for nvim-dap. (Please check the license of the package before using it.)
   - [vstuc](https://marketplace.visualstudio.com/items?itemName=VisualStudioToolsForUnity.vstuc)
   - [unity-debug](https://marketplace.visualstudio.com/items?itemName=deitry.unity-debug)


## Requrements

- Neovim >= 0.10.0
- [NeovimForUnity](https://github.com/nagaohiroki/NeovimForUnity) (Unity Package)

**optional**
- .NET SDK installed and `dotnet` command available(for vsutc debugger)
- mono (for unity-debugger)

## Installation


**Install the plugin with your preferred package manager:**

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'nagaohiroki/unity.nvim',
    opts = {
        discover_time = 2000 -- default option
    }
}
```

[nvim-dap](https://github.com/mfussenegger/nvim-dap) option

```lua
{
    'mfussenegger/nvim-dap',
    dependencies = {
        'nagaohiroki/unity.nvim',
    },
    config = function()
        local unity = require('unity')
        unity.setup_vstuc()
        -- unity.setup_unity_debugger() -- unity-debug(old)
    end
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
|  InstallUnityDebugger | Install [vstuc](https://marketplace.visualstudio.com/items?itemName=VisualStudioToolsForUnity.vstuc) \*1 |
|  InstallUnityDebuggerOld | Install [unity-debug](https://marketplace.visualstudio.com/items?itemName=deitry.unity-debug) \*1 |
|  UninstallUnityDebugger | Uninstall vstuc |
|  UninstallUnityDebuggerOld | Uninstall unity-debug |

\*1 Installed debugger path.
- **Linux** or **MacOS**: `~/.local/share/nvim/unity-debugger`
- **Windows**: `%LOCALAPPDATA%\nvim-data\unity-debugger`
