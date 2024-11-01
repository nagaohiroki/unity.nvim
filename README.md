# unity.nvim

This is a Neovim plugin for Unity

- Neovim commands for controlling Unity.
- Configuration options for nvim-dap. (Please check the license of the package before using it.)
   - [vstuc](https://marketplace.visualstudio.com/items?itemName=VisualStudioToolsForUnity.vstuc)
   - [unity-debug](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/deitry)


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
    "nagaohiroki/unity.nvim",
    opts = {}
}
```

[nvim-dap](https://github.com/mfussenegger/nvim-dap) option

```lua
{
    "mfussenegger/nvim-dap",
    dependencies = {
        'nagaohiroki/unity.nvim',
    },
    config = function()
        local dap = require('dap')
        local unity = require('unity')
        dap.adapters.vstuc = unity.vstuc_dap_adapter()
        -- dap.adapters.unity = unity.unity_dap_adapter() -- old debugger
        dap.configurations.cs = {
            --	unity.unity_dap_configuration(), -- old debugger
            unity.vstuc_dap_configuration()
        }
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
|  UPlayToggle | Toggle Play Unity |
|  UPauseToggle | Toggle Pause Unity |
|  InstallUnityDebugger | Install [vstuc](https://marketplace.visualstudio.com/items?itemName=VisualStudioToolsForUnity.vstuc) \*1 |
|  InstallUnityDebuggerOld | Install [unity-debug](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/deitry) \*1 |

\*1 debugger install directory.
- **Linux** or **MacOS**: `~/.local/share/nvim/unity-degger`
- **Windows**: `%LOCALAPPDATA%\nvim-data\unity-degger`
