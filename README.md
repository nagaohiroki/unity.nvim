# unity.nvim

This is a Neovim plugin for Unity

- Unity Play/Stop/Refresh with Neovim commands.

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
```

| Command |   |
| ------------- | -------------- |
|  URefresh | Refresh Unity |
|  UPlay | Play Unity |
|  UPause | Pause Unity |
|  UOpen | Open Unity Editor from source files |
|  UClose | Close Unity Editor  |

