# unity.nvim

This is a Neovim plugin for Unity

- Unity Play/Refresh/Open/Close with Neovim commands.

## Requrements

- Neovim >= 0.10.0
- unity cli >= 1.0.0-beta.15(Unity >= 6000.6)
- unity pipeline >= 0.9.1-exp.1

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
|  UOpen | Open Unity Editor |
|  UClose | Close Unity Editor |

