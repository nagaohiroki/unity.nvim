local M = {}
local function dap_config_editor()
  local editor_instance_path = vim.fs.joinpath('Library', 'EditorInstance.json')
  local editor_instance = vim.fn.findfile(editor_instance_path, '.;')
  if type(editor_instance) ~= 'string' or editor_instance == '' then return {} end
  local file = io.open(editor_instance, 'r')
  if file == nil then
    vim.print('cannot open ' .. editor_instance)
    return {}
  end
  local json = file:read('a')
  local obj = vim.json.decode(json)
  file:close()
  local project_path = vim.fs.dirname(vim.fs.dirname(editor_instance))
  return {
    type = 'monodbg',
    request = 'attach',
    name = vim.fs.basename(project_path) .. ' pid:' .. obj.process_id,
    debugPort = 56000 + (obj.process_id % 1000),
    cwd = project_path
  }
end
local function dap_adapter()
  return
  {
    type = 'executable',
    command = vim.g.unitydbg,
    name = 'Unity Debugger',
  }
end
function M.setup()
  local success, dap = pcall(require, 'dap')
  if not success then return end
  dap.providers.configs.cs = function(bufnr)
    if vim.bo[bufnr].filetype ~= 'cs' then return {} end
    if vim.g.unitydbg == nil or vim.fn.executable(vim.g.unitydbg) == 0 then
      return {}
    end
    dap.adapters.monodbg = dap_adapter()
    return { dap_config_editor() }
  end
end

return M
