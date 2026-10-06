# unity.nvim

This is a Neovim plugin for Unity

- Unity Play/Stop/Refresh/Open/Close with Neovim commands.

## Requrements

- Neovim >= 0.10.0
- unity cli(Unity >= 6000)
- unity pipeline

``` bash
unity pipeline install
```

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

