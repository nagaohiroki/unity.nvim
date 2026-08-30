local M = {}
local function has_unity_cli()
  if vim.fn.executable('unity') ~= 0 then return true end
  vim.notify(
    'unity.nvim: This feature requires the unity CLI command.\n' ..
    'Please ensure that the Unity CLI (Unity 6 or later) is installed and included in your PATH.',
    vim.log.levels.ERROR)
  return false
end
local function unity_command(command, on_success)
  if not has_unity_cli() then return end
  vim.system(command, { text = true }, function(obj)
    local result = vim.json.decode(obj.stdout)
    if result.success == false then
      vim.schedule(function()
        vim.notify(result.errors[1].message, vim.log.levels.ERROR)
      end)
      return
    end
    on_success(result)
  end)
end
local function show_errors()
  unity_command({ 'unity', 'command', 'get_console_logs', '--json' },
    function(obj)
      local result = obj.data.result
      local logs = result.logs
      local list = {}
      for _, log in ipairs(logs) do
        local file, line, col, msg = log.message:match("([%w%s%_%-%./%\\]+)%(?(%d+)%,?(%d*)%)?%:%s*(.*)")
        table.insert(list, {
          filename = vim.fs.joinpath(obj.data.target.projectPath, file),
          lnum = tonumber(line),
          col = tonumber(col) or 1,
          text = msg,
          type = 'E'
        })
      end
      vim.schedule(function()
        if result.total == 0 then
          vim.cmd('cclose')
          vim.fn.setqflist({}, 'r')
        else
          vim.fn.setqflist(list, 'r')
          vim.cmd('copen')
        end
      end)
    end)
end
local function unity_play()
  unity_command({ 'unity', 'command', 'editor_status', '--json' },
    function(obj)
      local status = obj.data.result.status
      if status == 'ready' then
        unity_command({ 'unity', 'command', 'editor_play', '--json' }, function(_) end)
      end
      if status == 'playing' then
        unity_command({ 'unity', 'command', 'editor_stop', '--json' }, function(_) end)
      end
    end
  )
end
local function unity_recompile()
  unity_command({ 'unity', 'command', 'recompile', '--json' },
    function(_) vim.defer_fn(show_errors, 2000) end)
end
local function unity_pause()
  unity_command({ 'unity', 'command', 'editor_pause', '--json' }, function(_) end)
end
local function unity_open()
  local dir = vim.fs.root(vim.api.nvim_buf_get_name(0), { 'ProjectSettings', 'Assets' })
  unity_command({ 'unity', 'open', dir, '--json' }, function(_) end)
end
local function unity_close()
  unity_command({ 'unity', 'command', 'eval', 'UnityEditor.EditorApplication.Exit(0);', '--json' }, function(_) end)
end
local function create_user_commands()
  vim.api.nvim_create_user_command('UPlay', unity_play, {})
  vim.api.nvim_create_user_command('URefresh', unity_recompile, {})
  vim.api.nvim_create_user_command('UPause', unity_pause, {})
  vim.api.nvim_create_user_command('UOpen', unity_open, {})
  vim.api.nvim_create_user_command('UClose', unity_close, {})
end
function M.setup()
  create_user_commands()
end

return M
