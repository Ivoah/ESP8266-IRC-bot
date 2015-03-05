nick = "ESPBot"
server = {"irc.freenode.net", 6667}
channels = {"#esp8266"}
dead = true

DEBUG = true

function connection(irc)
    dead = false
    irc:send("NICK " .. nick .. "\r\n")
    irc:send("USER " .. nick .. " 8 * :" .. nick .. "\r\n")
    for i, channel in pairs(channels) do
        irc:send("JOIN " .. channel .. "\r\n")
    end
end

function receive(irc, text)
    if DEBUG then print(text) end
    if text:find("PING :") then
        irc:send("PONG :" .. string.sub(text, 7))
    elseif text:find("PRIVMSG") then
        -- :Ivoah!~Ivoah@192.168.1.70 PRIVMSG #banana :hi
        local _, i = text:find("PRIVMSG")
        local chnl_msg = text:sub(i + 2)
        local i = chnl_msg:find(":")
        local v = text:find("!")
        if v then
            chnl_msg = chnl_msg:gsub("ACTION", text:sub(2, v - 1))
            handle_message(text:sub(2, v - 1), chnl_msg:sub(1, i - 2), chnl_msg:sub(i + 1))
        end
    elseif text:find("NICK") then
        -- :Ivoah!~Ivoah@192.168.1.70 NICK :ba
        local _, i = text:find("NICK")
        local v = text:find("!")
        if v then
            print(text:sub(2, v - 1) .. " is now known as " .. text:sub(i + 3))
        end
    elseif text:find("PART") then
        --:Ivoah!~Ivoah@p-74-209-20-44.dsl1.rtr.chat.fpma.frpt.net PART #esp8266 :"Leaving..."
        local _, i = text:find("PART")
        local chnl_msg = text:sub(i + 2)
        local i = chnl_msg:find(":")
        local v = text:find("!")
        if v then
            print(text:sub(2, v - 1) .. " has left " .. chnl_msg:sub(1, i - 2) .. "(" .. chnl_msg:sub(i + 1) .. ")\r\n")
        end
    elseif text:find("QUIT") then
        --:SpeedEvil!~quassel@tor/regular/SpeedEvil QUIT :Read error: Connection reset by peer
        local _, i = text:find("QUIT")
        local chnl_msg = text:sub(i + 2)
        local i = chnl_msg:find(":")
        local v = text:find("!")
        if v then
            print(text:sub(2, v - 1) .. " has left IRC " .. "(" .. chnl_msg:sub(i + 1) .. ")\r\n")
        end
    elseif text:find("JOIN") then
        --:Ivoah!~Ivoah@p-74-209-20-44.dsl1.rtr.chat.fpma.frpt.net JOIN #esp8266
        local _, i = text:find("JOIN")
        local chnl = text:sub(i + 2)
        local v = text:find("!")
        if v then
            print(text:sub(2, v - 1) .. " has joined " .. chnl .. "\r\n")
        end
    end
end

function disconnection(irc)
    print("Connection closed")
    dead = true
end

function handle_message(usr, chnl, msg)
    if chnl == nick then chnl = usr end
    print("Message from " .. usr .. " in " .. chnl .. ": " .. msg)
    if chnl == usr or msg:find(nick) then
        send_message(chnl, "Hi there " .. usr)
    elseif msg:find("~") == 1 then
        --~google esp8266 irc bot
        local cmd = split(msg)
        handle_command(chnl, cmd[1]:sub(2), {select(2, unpack(cmd))})
    end
end

function handle_command(chnl, cmd, args)
    if cmd == "google" then
        send_message(chnl, "http://google.com/search&q=" .. url_encode(table.concat(args, " ")))
    elseif cmd == "d" then
        if #args ~= 0 and #args ~= 1 then
            send_message(chnl, "Usage: ~d [sides] (default: 6)")
        end
        local n = math.floor(tonumber(args[1]) or 6)
        send_message("d" .. n .. " roll: " .. math.random(n))

    end
end

function send_message(chnl, msg)
    irc:send("PRIVMSG " .. chnl .. " :" .. msg .. "\r\n")
end

function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    local i = 1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

function url_encode(str)
  if str then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w %-%_%.%~])", function (c)
        return string.format ("%%%02X", string.byte(c))
    end)
    str = string.gsub (str, " ", "+")
  end
  return str
end

math.randomseed(adc.read(0))

irc = net.createConnection(net.TCP, 0)
irc:on("connection", connection)
irc:on("receive", receive)
irc:on("disconnection", disconnection)
irc:connect(server[2], server[1])

tmr.alarm(0, 60000, 1, function()
    if dead then
        print("Reconnecting...")
        irc:connect(server[2], server[1])
    end
end)
