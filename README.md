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
    'nagaohiroki/nvim-dap', -- Fixed vstuc error(See Note)
    dependencies = {
        'nagaohiroki/unity.nvim',
    },
    config = function()
        local dap = require('dap')
        vim.keymap.set('n', '<F5>', function()
            if dap.session() == nil then
                local unity = require('unity')
                -- vstuc
                dap.adapters.vstuc = unity.vstuc_dap_adapter()
                dap.configurations.cs = unity.vstuc_dap_configuration()
                -- unity-debug(old)
                -- dap.adapters.unity = unity.unity_dap_adapter()
                -- dap.configurations.cs = { unity.unity_dap_configuration() }
            end
            dap.continue()
        end)
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
|  ShowUnityProcess | Show Debug Target Info |
|  InstallUnityDebugger | Install [vstuc](https://marketplace.visualstudio.com/items?itemName=VisualStudioToolsForUnity.vstuc) \*1 |
|  InstallUnityDebuggerOld | Install [unity-debug](https://marketplace.visualstudio.com/items?itemName=deitry.unity-debug) \*1 |

\*1 Installed debugger path.
- **Linux** or **MacOS**: `~/.local/share/nvim/unity-degger`
- **Windows**: `%LOCALAPPDATA%\nvim-data\unity-degger`


## Note

vstuc on nvim-dap is not working.  
Adding filterOptions to nvim-dap's setExceptionBreakpoints made it work.

[mfussenegger/nvim-dap/lua/dap/session.lua](https://github.com/mfussenegger/nvim-dap/blob/master/lua/dap/session.lua#L999)  

``` diff
- { filters = filters, exceptionOptions = exceptionOptions },  
+ { filters = filters, exceptionOptions = exceptionOptions, filterOptions = {} },  
```

or wait for vstuc next version. [see](https://github.com/microsoft/vscode-dotnettools/issues/1705)
