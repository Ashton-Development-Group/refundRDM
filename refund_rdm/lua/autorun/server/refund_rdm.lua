RefundRDM = RefundRDM or {}
RefundRDM.DeathLogs = RefundRDM.DeathLogs or {}

RefundRDM.ValidWeaponClasses = {
    weapon_physgun = true,
    weapon_physcannon = true,
    weapon_crowbar = true,
    weapon_pistol = true,
    weapon_smg1 = true,
    weapon_frag = true,
    weapon_shotgun = true,
    weapon_ar2 = true,
    weapon_rpg = true,
}

function RefundRDM:IsValidWeaponClass(class)
    return self.ValidWeaponClasses[class] or false
end

function RefundRDM:LogPlayerDeath(victim, attacker, dmginfo)
    if not IsValid(victim) then return nil end

    local deathLog = {
        victim = victim:SteamID64(),
        victimName = victim:Nick(),
        attacker = IsValid(attacker) and attacker:SteamID64() or "Unknown", 
        attackerName = IsValid(attacker) and attacker:Nick() or "Unknown",
        time = os.time(),
        weapons = {},
        ammo = {},
        inventory = {}
    }

    for _, weapon in pairs(victim:GetWeapons()) do
        local weaponClass = weapon:GetClass()
        
        if self:IsValidWeaponClass(weaponClass) then
            table.insert(deathLog.weapons, {
                class = weaponClass,
                ammo = victim:GetAmmoCount(weapon:GetPrimaryAmmoType()),
                printName = weapon:GetPrintName() or weaponClass,
                slot = weapon:GetSlot()
            })
        end
    end

    for _, ammoType in pairs(game.GetAmmoTypes()) do
        local ammoCount = victim:GetAmmoCount(ammoType)
        if ammoCount > 0 then
            deathLog.ammo[ammoType] = ammoCount
        end
    end

    if not RefundRDM.DeathLogs[victim:SteamID64()] then
        RefundRDM.DeathLogs[victim:SteamID64()] = {}
    end
    table.insert(RefundRDM.DeathLogs[victim:SteamID64()], deathLog)

    if #RefundRDM.DeathLogs[victim:SteamID64()] > 50 then
        table.remove(RefundRDM.DeathLogs[victim:SteamID64()], 1)
    end

    return deathLog
end

function RefundRDM:RefundPlayerDeath(ply, deathLog)
    if not IsValid(ply) then return false end

    ply:StripWeapons()

    for k, weaponData in pairs(deathLog.weapons) do
        if self:IsValidWeaponClass(weaponData.class) then
            local weapon = ply:Give(weaponData.class)
            if weapon then
                ply:SetAmmo(weaponData.ammo, weapon:GetPrimaryAmmoType())
                
                if k == 1 then
                    ply:SelectWeapon(weapon:GetClass())
                end

                print(string.format("RefundRDM: Refunded weapon %s to %s", weaponData.class, ply:Nick()))
            else
                print(string.format("RefundRDM: Failed to refund weapon %s to %s", weaponData.class, ply:Nick()))
            end
        end
    end

    return true
end

hook.Add("PlayerDeath", "RefundRDM_LogDeath", function(victim, inflictor, attacker)
    RefundRDM:LogPlayerDeath(victim, attacker, nil)
end)

util.AddNetworkString("RefundRDM_OpenMenu")
util.AddNetworkString("RefundRDM_RequestDeathLogs")
util.AddNetworkString("RefundRDM_PerformRefund")

net.Receive("RefundRDM_RequestDeathLogs", function(len, ply)
    if not ply:IsAdmin() then 
        ply:ChatPrint("You do not have permission to access death logs.")
        return 
    end

    local targetSteamID64 = net.ReadString()
    
    net.Start("RefundRDM_RequestDeathLogs")
    net.WriteTable(RefundRDM.DeathLogs[targetSteamID64] or {})
    net.Send(ply)
end)

net.Receive("RefundRDM_PerformRefund", function(len, ply)
    if not ply:IsAdmin() then 
        ply:ChatPrint("You do not have permission to perform refunds.")
        return 
    end

    local targetSteamID64 = net.ReadString()
    local deathIndex = net.ReadInt(32)

    local target = player.GetBySteamID64(targetSteamID64)
    if not IsValid(target) then 
        ply:ChatPrint("Target player is no longer on the server.")
        return 
    end

    local deathLog = RefundRDM.DeathLogs[targetSteamID64] and RefundRDM.DeathLogs[targetSteamID64][deathIndex]
    if deathLog then
        local success = RefundRDM:RefundPlayerDeath(target, deathLog)
        
        if success then
            ply:ChatPrint(string.format("Refunded death log for %s", target:Nick()))
            target:ChatPrint(string.format("An admin has refunded your items from a previous death"))
        else
            ply:ChatPrint("Failed to refund death log.")
        end
    else
        ply:ChatPrint("Could not find the specified death log.")
    end
end)

concommand.Add("refundrdm_menu", function(ply, cmd, args)
    if not ply:IsAdmin() then 
        ply:ChatPrint("You do not have permission to use this command.")
        return 
    end
    
    net.Start("RefundRDM_OpenMenu")
    net.Send(ply)
end)

MsgC(Color(0, 255, 0), "[RefundRDM] Server-side script loaded successfully!\n")
