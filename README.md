# unity.nvim

This is a Neovim plugin for Unity

- Unity Play/Stop/Refresh with Neovim commands.
- nvim-dap configuration for Unity (using DotRush)

## Requrements

- Neovim >= 0.10.0
- [NeovimForUnity](https://github.com/nagaohiroki/NeovimForUnity) (Unity Package)
- .NET SDK installed and `dotnet` command available.

## Installation

* [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'nagaohiroki/unity.nvim',
  ft = { 'cs' }, 
  opts = {},
},
{
  'JaneySprings/DotRush',
  build = 'dotnet publish src/DotRush.Debugging.Mono -c Release',
  config = function(plugin)
    vim.g.unitydbg = vim.fs.joinpath(plugin.dir, 'extension', 'bin', 'DebuggerMono', 'monodbg')
  end
}
```

| Command |   |
| ------------- | -------------- |
|  URefresh | Refresh Unity |
|  UPlay | Play Unity |
|  UPause | Pause Unity |
|  UOpen | Open Unity Editor from source files |
|  UClose | Close Unity Editor  |

