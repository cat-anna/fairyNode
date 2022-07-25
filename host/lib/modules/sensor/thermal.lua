
function SysInfo:InitThermalNode(client)
    self.thermal_props = {}

    if lfs.attributes("/sys/class/thermal") then
        for entry in lfs.dir("/sys/class/thermal") do
            if entry ~= "." and entry ~= ".." and entry ~= "init.lua" and entry:match("thermal_zone%d+") then
                local base_path = "/sys/class/thermal/" .. entry
                local e = {
                    name = read_first_line(base_path .. "/type"),
                    unit = "C",
                    datatype = "float",
                    _read_path = base_path .. "/temp",
                }
                table.insert(self.thermal_props, e)
            end
        end
        self.thermal_node = client:AddNode("thermal", {
            ready = true,
            name = "Temperatures",
            properties = self.thermal_props
        })
    else
        self.thermal_node = nil
        print("SYSINFO: /sys/class/thermal does not exist")
    end
end


function SysInfo:ReadSensors()
    if self.thermal_node then
        for id, e in pairs(self.thermal_props) do
            self.thermal_node:SetValue(id, string.format("%.1f", tonumber(read_first_line(e._read_path)) / 1000))
        end
    end
end
