local M = {}
M._config = {
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
      version   = '1.1.1',
    },
    unity_debug =
    {
      publisher = 'deitry',
      extension = 'unity-debug',
      version   = '3.0.11',
    },
  },
}

local function find_path(target)
  local path = vim.fn.expand('%:p')
  while true do
    local new_path = vim.fn.fnamemodify(path, ':h')
    if new_path == path then
      return ''
    end
    path = new_path
    local target_path = vim.fn.glob(vim.fs.joinpath(path, target))
    if target_path ~= '' then
      return path
    end
  end
end

local function find_editor_instance_json()
  local editor_instance = vim.fs.joinpath('Library', 'EditorInstance.json')
  return vim.fs.joinpath(find_path(editor_instance), editor_instance)
end
local function get_process_id()
  local editor_instance = find_editor_instance_json()
  local file = io.open(editor_instance, 'r')
  if file == nil then
    vim.print('cannot open ' .. editor_instance)
    return nil
  end
  local text = file:read('a')
  local json = vim.json.decode(text)
  file:close()
  return json.process_id
end
local function unity_debugger_port()
  local process_id = get_process_id()
  if process_id == nil then
    return nil
  end
  return 56000 + (process_id % 1000)
end
local function unity_message_port()
  local debugger_port = unity_debugger_port()
  if debugger_port == nil then
    return nil
  end
  return debugger_port + 2
end

local function request(tbl)
  local messager_port = unity_message_port()
  if messager_port == nil then return end
  local udp = vim.uv.new_udp()
  if udp == nil then return end
  local json = vim.fn.json_encode(tbl)
  vim.uv.udp_send(udp, json, '127.0.0.1', messager_port, function(err)
    if err then
      vim.print('error:', err)
    end
    vim.uv.close(udp)
  end)
end

local function download_debugger(path, url)
  local dir = vim.fn.fnamemodify(path, ':h');
  local out = path .. '.zip'
  vim.fn.mkdir(dir, 'p')
  vim.print('start download.' .. url)
  vim.system({ 'curl', '--compressed', '-L', url, '-o', out }, { text = true }, function(_)
    vim.print('start extract')
    vim.system({ 'tar', 'xf', out, '-C', dir }, { text = true }, function(_)
      vim.uv.fs_rename(vim.fs.joinpath(dir, 'extension'), path, function(rename_err)
        vim.print('done ' .. path)
        if rename_err then
          vim.print(rename_err)
        end
        local extension_files = { 'extension.vsixmanifest', '[Content_Types].xml' }
        for _, v in pairs(extension_files) do
          vim.uv.fs_rename(vim.fs.joinpath(dir, v), vim.fs.joinpath(path, v))
        end
        vim.schedule(function()
          vim.fn.delete(out)
        end)
      end)
    end)
  end)
end

local function get_install_name(debugger_name)
  local debugger = M._config.debuggers[debugger_name]
  local path = string.format('%s.%s-%s', debugger.publisher, debugger.extension, debugger.version)
  return string.lower(path)
end

local function get_marketplace_url(debugger_name)
  local debugger = M._config.debuggers[debugger_name]
  local marketplace =
  'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/%s/vsextensions/%s/%s/vspackage'
  return string.format(marketplace, debugger.publisher, debugger.extension, debugger.version)
end

local function install_debugger(debugger_name)
  local path = get_install_name(debugger_name)
  local url = get_marketplace_url(debugger_name)
  local dir = vim.fs.joinpath(M._config.install_path, path)
  download_debugger(dir, url)
end

local function get_path(debugger_name)
  local debugger_path = get_install_name(debugger_name)
  local install = vim.fs.joinpath(M._config.install_path, debugger_path)
  if vim.fn.isdirectory(install) == 1 then
    return install
  end
  local vscode_install = vim.fs.joinpath(M._config.install_path_vscode, debugger_path)
  if vim.fn.isdirectory(vscode_install) == 1 then
    return vscode_install
  end
  vim.print(install .. ' and ' .. vscode_install .. ' not found')
  return ''
end

local function unity_attach_probs()
  vim.notify('searching proccess...')
  local probs = {}
  local system_obj = vim.system(
    { 'dotnet', vim.fs.joinpath(get_path('vstuc'), 'bin', 'UnityAttachProbe.dll') },
    { text = true, stdin = true })
  local completed = system_obj:wait(M._config.discover_time)
  local stdout = completed.stdout
  if stdout == nil or #stdout == 0 then
    print('No endpoint found (is unity running?)')
    return nil
  end
  for json in vim.gsplit(stdout, '\n') do
    if json ~= '' then
      local probe = vim.json.decode(json)
      for _, p in pairs(probe) do
        if p.isBackground == false then
          local is_unique = true
          for _, v in pairs(probs) do
            if v.debuggerPort == p.debuggerPort then
              is_unique = false
            end
          end
          if is_unique == true then
            probs[#probs + 1] = p
          end
        end
      end
    end
  end
  vim.notify('done.')
  return probs
end

local function vstuc_dap_adapter()
  return {
    type = 'executable',
    command = 'dotnet',
    args = { vim.fs.joinpath(get_path('vstuc'), 'bin', 'UnityDebugAdapter.dll') },
    name = 'Attach to Unity'
  }
end

local function vstuc_dap_configuration()
  if vim.bo.filetype ~= 'cs' then
    return
  end
  local probs = unity_attach_probs()
  if probs == nil then
    vim.notify('No endpoint found (is unity running?)')
    return nil
  end
  local tbl = {}
  for _, p in ipairs(probs) do
    local address = p.address .. ':' .. p.debuggerPort
    local name = string.format('%s(%s:%s) %s pid:%s', p.projectName, p.machine, p.type, address, p.processId)
    if p.unityPlayer ~= vim.NIL then
      name = string.format('%s(%s)', name, p.unityPlayer.packageName)
    end
    tbl[#tbl + 1] = {
      type = 'vstuc',
      request = 'attach',
      name = name,
      logFile = vim.fs.joinpath(vim.fn.stdpath('data'), 'dap_vstuc_' .. p.type .. '.log'),
      endPoint = address
    }
  end
  return tbl
end

local function unity_dap_adapter()
  local unityDebugCommand = vim.fs.joinpath(get_path('unity_debug'), 'bin', 'UnityDebug.exe')
  local unityDebugArgs = {}
  if vim.fn.has('win32') == 0 then
    unityDebugArgs = { unityDebugCommand }
    unityDebugCommand = 'mono'
  end
  return {
    type = 'executable',
    command = unityDebugCommand,
    args = unityDebugArgs,
    name = 'Unity Editor',
  }
end

local function unity_dap_configuration()
  return {
    type = 'unity',
    request = 'launch',
    name = 'Unity Editor',
    path = function() return find_editor_instance_json() end
  }
end

local function setup_dap()
  local success, dap = pcall(require, 'dap')
  if not success then
    return
  end
  dap.providers.configs.cs = function(_)
    if M._config.debugger == 'unity-debug' then
      dap.adapters.unity = unity_dap_adapter()
      return { unity_dap_configuration() }
    end
    if M._config.debugger == 'vstuc' then
      dap.adapters.vstuc = vstuc_dap_adapter()
      return vstuc_dap_configuration()
    end
  end
end

local function create_user_commands()
  local functionTbl = {
    'Refresh',
    'Play',
    'Pause',
    'Unpause',
    'Stop',
  }
  for _, v in ipairs(functionTbl) do
    vim.api.nvim_create_user_command('U' .. v, function()
      request({ Type = v, Value = '' })
    end, {})
  end

  vim.api.nvim_create_user_command('UnityDebuggerInstall', function(opts)
      install_debugger(opts.fargs[1])
    end,
    {
      nargs = 1,
      complete = function(_, _, _)
        local names = {}
        for name, _ in pairs(M._config.debuggers) do
          names[#names + 1] = name
        end
        return names
      end
    })

  vim.api.nvim_create_user_command('UnityDebuggerUninstall', function(opts)
      vim.fn.delete(vim.fs.joinpath(M._config.install_path, opts.fargs[1]), 'rf')
    end,
    {
      nargs = 1,
      complete = function(_, _, _)
        local names = {}
        for name, _ in vim.fs.dir(M._config.install_path) do
          if name ~= '.' and name ~= '..' then
            names[#names + 1] = name
          end
        end
        return names
      end
    })

  vim.api.nvim_create_user_command('ShowUnityProcess', function()
    local probs = unity_attach_probs()
    if probs == nil then
      vim.print('No endpoint found (is unity running?)')
      return
    end
    for _, p in ipairs(probs) do
      vim.print(p)
    end
  end, {})
end

function M.setup(config)
  M._config = vim.tbl_deep_extend('force', M._config, config or {})
  setup_dap()
  create_user_commands()
end

return M
