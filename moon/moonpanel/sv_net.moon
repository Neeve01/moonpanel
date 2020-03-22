util.AddNetworkString "TheMP EditorData Req"
util.AddNetworkString "TheMP EditorData"

util.AddNetworkString "TheMP Flow"

util.AddNetworkString "TheMP Editor"
util.AddNetworkString "TheMP Focus"
util.AddNetworkString "TheMP Notify"
util.AddNetworkString "TheMP Reload"

concommand.Add "themp_reload", ->
    timer.Simple 0, ->
        include "autorun/moonpanel.lua"

    net.Start "TheMP Reload"
    net.Broadcast!

Moonpanel.sendNotify = (ply, message, sound, type) =>
    net.Start "TheMP Notify"
    net.WriteString message
    net.WriteString sound
    net.WriteUInt type, 8
    net.Send ply

Moonpanel.broadcastFinish = (panel, data) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.PuzzleFinish, Moonpanel.FlowSize
    net.WriteEntity panel

    raw = util.Compress util.TableToJSON data
    net.WriteUInt #raw, 32
    net.WriteData raw, #raw

    net.Broadcast!

Moonpanel.broadcastStart = (panel, node, symmNode) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.PuzzleStart, Moonpanel.FlowSize
    net.WriteEntity panel

    net.WriteFloat node.x
    net.WriteFloat node.y
    net.WriteBool symmNode and true or false

    if symmNode
        net.WriteFloat symmNode.x
        net.WriteFloat symmNode.y
    net.Broadcast!

Moonpanel.broadcastDeltas = (ply, panel, x, y) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.ApplyDeltas, Moonpanel.FlowSize
    net.WriteEntity panel

    x, y = math.Clamp(Moonpanel.trunc(x, 3), -100, 100), math.Clamp(Moonpanel.trunc(y, 3), -100, 100)
    net.WriteFloat x
    net.WriteFloat y
    net.SendOmit ply

Moonpanel.broadcastDesync = (panel) =>
    net.Start "TheMP Flow"
    net.WriteUInt Moonpanel.Flow.Desync, Moonpanel.FlowSize
    net.WriteEntity panel
    net.Broadcast!

Moonpanel.pendingEditorData = {}
pendingEditorData = Moonpanel.pendingEditorData

counter = 1
Moonpanel.requestEditorConfig = (ply, callback, errorcallback) =>
    pending = {
        player: ply
        callback: callback
        timer: "TheMP RemovePending #{tostring counter}"
    }
    pendingEditorData[#pendingEditorData + 1] = pending

    counter = (counter % 10000) + 1

    net.Start "TheMP EditorData Req"
    net.Send ply
    
    timer.Create pending.timer, 4, 1, () ->
        errorcallback!
        for i = 1, #pendingEditorData
            if pendingEditorData[i] == pending
                table.remove pendingEditorData, i
                break

net.Receive "TheMP Flow", (len, ply) ->
    flowType = net.ReadUInt Moonpanel.FlowSize
    
    switch flowType
        when Moonpanel.Flow.RequestControl
            panel = net.ReadEntity!

            x = net.ReadUInt 10
            y = net.ReadUInt 10

            Moonpanel\requestControl ply, panel, x, y

        when Moonpanel.Flow.ApplyDeltas
            panel = ply\GetNW2Entity "TheMP Controlled Panel"
            if IsValid panel
                x = net.ReadFloat!
                y = net.ReadFloat!

                panel\ApplyDeltas x, y

        when Moonpanel.Flow.RequestData
            panel = net.ReadEntity!
            if not panel.pathFinder
                return

            data = {
                tileData: panel.tileData
                cursors: panel.pathFinder.cursors
                lastSolution: panel.lastSolution
            }

            data.stacks = {}
            for _, nodeStack in pairs panel.pathFinder.nodeStacks
                stack = {}
                data.stacks[#data.stacks + 1] = stack

                for _, node in pairs nodeStack
                    stack[#stack + 1] = panel.pathFinder.nodeIds[node]

            raw = util.Compress util.TableToJSON data

            net.Start "TheMP Flow"
            net.WriteUInt Moonpanel.Flow.PanelData, Moonpanel.FlowSize

            net.WriteEntity panel
            net.WriteUInt #raw, 32
            net.WriteData raw, #raw

            net.Send ply

net.Receive "TheMP EditorData", (len, ply) ->
    pending = nil
    pendingEditorData = Moonpanel.pendingEditorData

    for k, v in pairs pendingEditorData
        if v.player == ply
            pending = v
            break

    if not pending
        return

    for i = 1, #pendingEditorData
        if pendingEditorData[i] == pending
            table.remove pendingEditorData, i
            break

    timer.Remove pending.timer

    length = net.ReadUInt 32
    raw = net.ReadData length
    
    data = util.JSONToTable((util.Decompress raw) or "{}") or {}
    data = Moonpanel\sanitizeTileData data

    pending.callback data