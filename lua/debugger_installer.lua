local M = {}
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

local function get_install_name(debugger_name, config)
  local debugger = config.debuggers[debugger_name]
  local path = string.format('%s.%s-%s', debugger.publisher, debugger.extension, debugger.version)
  return string.lower(path)
end

local function get_marketplace_url(debugger_name, config)
  local debugger = config.debuggers[debugger_name]
  local marketplace =
  'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/%s/vsextensions/%s/%s/vspackage'
  return string.format(marketplace, debugger.publisher, debugger.extension, debugger.version)
end

local function install_debugger(debugger_name, config)
  local path = get_install_name(debugger_name, config)
  local url = get_marketplace_url(debugger_name, config)
  local dir = vim.fs.joinpath(config.install_path, path)
  download_debugger(dir, url)
end

function M.get_path(debugger_name, config)
  local debugger_path = get_install_name(debugger_name, config)
  local install = vim.fs.joinpath(config.install_path, debugger_path)
  if vim.fn.isdirectory(install) == 1 then
    return install
  end
  local vscode_install = vim.fs.joinpath(config.install_path_vscode, debugger_path)
  if vim.fn.isdirectory(vscode_install) == 1 then
    return vscode_install
  end
  vim.print(install .. ' and ' .. vscode_install .. ' not found')
  return ''
end

function M.create_user_commands(config)
  vim.api.nvim_create_user_command('UnityDebuggerInstall', function(opts)
      install_debugger(opts.fargs[1], config)
    end,
    {
      nargs = 1,
      complete = function(_, _, _)
        local names = {}
        for name, _ in pairs(config.debuggers) do
          names[#names + 1] = name
        end
        return names
      end
    })

  vim.api.nvim_create_user_command('UnityDebuggerUninstall', function(opts)
      vim.fn.delete(vim.fs.joinpath(config.install_path, opts.fargs[1]), 'rf')
    end,
    {
      nargs = 1,
      complete = function(_, _, _)
        local names = {}
        for name, _ in vim.fs.dir(config.install_path) do
          if name ~= '.' and name ~= '..' then
            names[#names + 1] = name
          end
        end
        return names
      end
    })
end

return M
