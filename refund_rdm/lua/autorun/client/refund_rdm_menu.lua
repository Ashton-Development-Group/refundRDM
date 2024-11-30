function table.map(t, fn)
    local newTable = {}
    for k, v in pairs(t) do
        newTable[k] = fn(v)
    end
    return newTable
end

local function CreateRefundMenu()
    local frame = vgui.Create("DFrame")
    frame:SetSize(900, 650)
    frame:SetTitle("RefundRDM - Player Death Management")
    frame:SetIcon("icon16/shield.png")
    frame:Center()
    frame:MakePopup()

    function frame:Paint(w, h)
        surface.SetDrawColor(40, 40, 40, 245)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(60, 60, 60, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local headerPanel = vgui.Create("DPanel", frame)
    headerPanel:SetPos(0, 0)
    headerPanel:SetSize(frame:GetWide(), 40)
    headerPanel.Paint = function(self, w, h)
        surface.SetDrawColor(30, 30, 30, 255)
        surface.DrawRect(0, 0, w, h)
    end

    local closeButton = vgui.Create("DButton", frame)
    closeButton:SetPos(frame:GetWide() - 110, 10)
    closeButton:SetSize(100, 30)
    closeButton:SetText("Close")
    closeButton:SetFont("DermaLarge")
    closeButton:SetTextColor(color_white)

    closeButton.Paint = function(self, w, h)
        surface.SetDrawColor(200, 0, 0, 255)
        surface.DrawRect(0, 0, w, h)
    
        surface.SetDrawColor(150, 0, 0, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end

    closeButton.DoClick = function()
        frame:Close()
    end

    local playerLabel = vgui.Create("DLabel", frame)
    playerLabel:SetPos(20, 50)
    playerLabel:SetText("Select Player:")
    playerLabel:SetColor(color_white)
    playerLabel:SizeToContents()

    local playerList = vgui.Create("DComboBox", frame)
    playerList:SetPos(20, 70)
    playerList:SetSize(250, 30)
    playerList:SetTextColor(color_white)
    playerList.Paint = function(self, w, h)
        surface.SetDrawColor(50, 50, 50, 255)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(80, 80, 80, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    for k, ply in pairs(player.GetAll()) do
        playerList:AddChoice(ply:Nick(), ply:SteamID64())
    end

    local deathLogList = vgui.Create("DListView", frame)
    deathLogList:SetPos(20, 110)
    deathLogList:SetSize(frame:GetWide() - 40, 450)
    deathLogList:SetMultiSelect(false)
    
    local timeCol = deathLogList:AddColumn("Time")
    local attackerCol = deathLogList:AddColumn("Attacker")
    local weaponsCol = deathLogList:AddColumn("Weapons")
    
    deathLogList.Paint = function(self, w, h)
        surface.SetDrawColor(50, 50, 50, 255)
        surface.DrawRect(0, 0, w, h)
    end
    deathLogList.m_bHideHeaders = false

    local currentDeathLogs = {}

    playerList.OnSelect = function(self, index, value, data)
        deathLogList:Clear()
        currentDeathLogs = {}
        
        net.Start("RefundRDM_RequestDeathLogs")
        net.WriteString(data)
        net.SendToServer()
    end

    net.Receive("RefundRDM_RequestDeathLogs", function()
        local deathLogs = net.ReadTable()
        currentDeathLogs = deathLogs
        
        for k, log in pairs(deathLogs) do
            local weaponsString = table.concat(
                table.map(log.weapons, function(weapon) 
                    return weapon.class 
                end), 
                ", "
            )

            deathLogList:AddLine(
                os.date("%Y-%m-%d %H:%M:%S", log.time), 
                log.attackerName, 
                weaponsString,
                k
            )
        end
    end)

    local refundButton = vgui.Create("DButton", frame)
    refundButton:SetPos(20, 570)
    refundButton:SetSize(frame:GetWide() - 40, 50)
    refundButton:SetText("Refund Selected Death")
    refundButton:SetEnabled(false)
    refundButton:SetFont("DermaLarge")
    
    refundButton.Paint = function(self, w, h)
        local color = self:IsEnabled() and 
            Color(70, 120, 220, 255) or 
            Color(100, 100, 100, 255)
        
        surface.SetDrawColor(color)
        surface.DrawRect(0, 0, w, h)
        
        surface.SetDrawColor(color.r * 0.8, color.g * 0.8, color.b * 0.8, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end

    deathLogList.OnRowSelected = function(self, rowIndex, row)
        refundButton:SetEnabled(true)
    end

    refundButton.DoClick = function()
        local selectedRow = deathLogList:GetSelectedLine()
        if not selectedRow then return end
        
        local index = deathLogList:GetLine(selectedRow):GetValue(4)
        local steamID64 = playerList:GetOptionData(playerList:GetSelectedID())
        
        index = tonumber(index)
        if not index then 
            print("Invalid death log index")
            return 
        end
        
        net.Start("RefundRDM_PerformRefund")
        net.WriteString(steamID64)
        net.WriteInt(index, 32)
        net.SendToServer()

        refundButton:SetEnabled(false)
    end
end

net.Receive("RefundRDM_OpenMenu", function()
    CreateRefundMenu()
end)

hook.Add("OnContextMenuOpen", "RefundRDM_AdminMenu", function()
    if LocalPlayer():IsAdmin() then
    end
end)
