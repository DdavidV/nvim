local M = {}

-- Connect a UI namespace to a table of event-name callbacks.
function M.attach(namespace, options, callbacks)
  vim.ui_attach(namespace, options, function(event, ...)
    local callback = callbacks[event]
    if callback then
      return callback(...)
    end
    -- Leave unregistered events unhandled so Neovim's other UIs can process them.
  end)
end

return M
