
local restserver_xavante = {}

local xavante = require("xavante")
local wsapi = require("wsapi.xavante")

local function start(self, logger)
   local rules = {}
   for path, _ in pairs(self.config.paths) do
      -- TODO support placeholders in paths
      rules[#rules + 1] = {
         match = path,
         with = wsapi.makeHandler(self.wsapi_handler)
      }
   end

   self.logger = logger

   -- HACK: There's no public API to change the server identification
   xavante._VERSION = "SGA"
   xavante.HTTP {
      server = {host = self.config.host or "*", port = self.config.port or 8080 },
      defaultHost = {
         rules = rules
      }
   }

   local ok, err = pcall(xavante.start, function()
      io.stdout:flush()
      io.stderr:flush()
      return false
   end, nil)

   if not ok then
      return nil, err
   end
   return true
end

function restserver_xavante.extend(self)
   self.start = start
end

return restserver_xavante

