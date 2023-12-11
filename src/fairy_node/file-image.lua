
local struct = require "struct"
local crc32 = require 'fairy_node/CRC32'
local file = require "pl.file"
local path = require "pl.path"

local m = {}

local FILE_SIGNATURE = "file"

function m.VersionHash()
   return "uid:a68989c774585d6a989be417cd9615b8"
end

function m.Pack(file_list)
   local out_buffer = {}
   local function put(block)
      table.insert(out_buffer, block)
   end

   table.sort(file_list)
   for k,v in pairs(file_list) do
      local file_name = path.basename(k)
      local file_data = v

      local block =
         table.concat(
         {
            struct.pack("B", file_name:len()),
            file_name,
            file_data,
         },
         ""
      )

      put(FILE_SIGNATURE)
      put(struct.pack("<I", block:len()))
      put(struct.pack("<I", crc32.Hash(block)))
      put(block)
   end

   return table.concat(out_buffer, "")
end

function m.Unpack(packed_image)
   local position = 0
   local function read(bytes)
      if position >= packed_image:len() then
         return ""
      end
      local block = packed_image:sub(position + 1, position + bytes)
      position = position + bytes
      return block
   end

   local files = { }

   while true do
      if position >= packed_image:len() then
         -- print("Extraction completed")
         return files
      end

      local header = read(12)
      if header:len() ~= 12 then
         print(header:len())
         error("Failed to read file header")
      end

      local signature, size, crc = struct.unpack("<c4II", header)
      if signature ~= FILE_SIGNATURE then
         error("invalid block signature")
      end
      local file_name_size = struct.unpack("b", read(1))
      local file_name = read(file_name_size)
      if file_name:len() ~= file_name_size then
         error("Failed to extract file name")
      end

      local file_data_size = size - file_name_size - 1
      local file_data = read(file_data_size)
      if file_data:len() ~= file_data_size then
         error("Failed to extract file data")
      end

      local read_crc = crc32.Hash(struct.pack("b", file_name_size) .. file_name .. file_data)
      if read_crc ~= crc then
         error("Block crc does not match")
      end

      files[file_name] = file_data
   end
end

return m
