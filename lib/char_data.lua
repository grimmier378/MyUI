local mq            = require('mq')
local CharData      = {}

local BuffTable     = {}
local SongTable     = {}
local DebuffOnMe    = {}
local MAX_SONGS     = 50
local MAX_PET_BUFFS = 60
local CheckIn       = 0
local numSlots      = 0
local numBuffs      = 0
local myPet         = mq.TLO.Pet

local btnInfo       = {
    attack = false,
    back = false,
    taunt = false,
    follow = false,
    guard = false,
    focus = false,
    sit = false,
    hold = false,
    stop = false,
    bye = false,
    regroup = false,
    report = false,
    swarm = false,
    kill = false,
    qattack = false,
    ghold = false,
}

--- Get My Data and return a table with the current values.
---@return table data
function CharData.GetMyData()
    local data = {}

    data.AAExp = mq.TLO.Me.AAExp() or 0
    data.AAPoints = mq.TLO.Me.AAPoints() or 0
    data.AAPointsSpent = mq.TLO.Me.AAPointsSpent() or 0
    data.AAPointsTotal = mq.TLO.Me.AAPointsTotal() or 0
    data.AAVitality = mq.TLO.Me.AAVitality() or 0
    data.AccuracyBonus = mq.TLO.Me.AccuracyBonus() or 0
    data.ActiveDisc = mq.TLO.Me.ActiveDisc() and mq.TLO.Me.ActiveDisc() or "None"
    data.ActiveFavorCost = mq.TLO.Me.ActiveFavorCost() or 0
    data.AltTimerReady = mq.TLO.Me.AltTimerReady()
    data.AGI = mq.TLO.Me.AGI() or 0
    data.AggroLock = mq.TLO.Me.AggroLock() and mq.TLO.Me.AggroLock.CleanName() or "None"
    data.AmIGroupLeader = mq.TLO.Me.AmIGroupLeader()
    data.AssistComplete = mq.TLO.Me.AssistComplete()
    data.AttackBonus = mq.TLO.Me.AttackBonus() or 0
    data.AttackSpeed = mq.TLO.Me.AttackSpeed() or 0
    data.AutoFire = mq.TLO.Me.AutoFire()
    data.AvoidanceBonus = mq.TLO.Me.AvoidanceBonus() or 0
    data.BardSongPlaying = mq.TLO.Me.BardSongPlaying()
    data.BaseSTR = mq.TLO.Me.BaseSTR() or 0
    data.BaseSTA = mq.TLO.Me.BaseSTA() or 0
    data.BaseCHA = mq.TLO.Me.BaseCHA() or 0
    data.BaseDEX = mq.TLO.Me.BaseDEX() or 0
    data.BaseINT = mq.TLO.Me.BaseINT() or 0
    data.BaseAGI = mq.TLO.Me.BaseAGI() or 0
    data.BaseWIS = mq.TLO.Me.BaseWIS() or 0
    data.BoundLocation = mq.TLO.Me.BoundLocation() or "None"
    data.Buyer = mq.TLO.Me.Buyer()
    data.CanMount = mq.TLO.Me.CanMount()
    data.CareerFavor = mq.TLO.Me.CareerFavor() or 0
    data.Cash = mq.TLO.Me.Cash() or 0
    data.CashBank = mq.TLO.Me.CashBank() or 0
    data.CastTimeLeft = mq.TLO.Me.CastTimeLeft() or 0
    data.CHA = mq.TLO.Me.CHA() or 0
    data.Charmed = mq.TLO.Me.Charmed() or "None"
    data.Chronobines = mq.TLO.Me.Chronobines() or 0
    data.ClairvoyanceBonus = mq.TLO.Me.ClairvoyanceBonus() or 0
    data.Class = mq.TLO.Me.Class() or "None"
    data.ClassShort = mq.TLO.Me.Class.ShortName() or "None"
    data.Combat = mq.TLO.Me.Combat()
    data.CombatEffectsBonus = mq.TLO.Me.CombatEffectsBonus() or 0
    data.CombatState = mq.TLO.Me.CombatState() or "Unknown"
    data.Copper = mq.TLO.Me.Copper() or 0
    data.CopperBank = mq.TLO.Me.CopperBank() or 0
    data.Corrupted = mq.TLO.Me.Corrupted() or "None"
    data.CountBuffs = mq.TLO.Me.CountBuffs() or 0
    data.CountersCorruption = mq.TLO.Me.CountersCorruption() or 0
    data.CountersCurse = mq.TLO.Me.CountersCurse() or 0
    data.CountersDisease = mq.TLO.Me.CountersDisease() or 0
    data.CountersPoison = mq.TLO.Me.CountersPoison() or 0
    data.CountSongs = mq.TLO.Me.CountSongs() or 0
    -- data.Counters = mq.TLO.Me.Counters() or 0
    data.CurrentEndurance = mq.TLO.Me.CurrentEndurance() or 0
    data.CurrentFavor = mq.TLO.Me.CurrentFavor() or 0
    data.CurrentHPs = mq.TLO.Me.CurrentHPs() or 0
    data.CurrentMana = mq.TLO.Me.CurrentMana() or 0
    data.CurrentWeight = mq.TLO.Me.CurrentWeight() or 0
    data.Cursed = mq.TLO.Me.Cursed() or "None"
    data.DamageShieldBonus = mq.TLO.Me.DamageShieldBonus() or 0
    data.DamageShieldMitigationBonus = mq.TLO.Me.DamageShieldMitigationBonus() or 0
    data.Dar = mq.TLO.Me.Dar() or 0
    data.Diseased = mq.TLO.Me.Diseased() or "None"
    data.DEX = mq.TLO.Me.DEX() or 0
    data.Dotted = mq.TLO.Me.Dotted() or "None"
    data.DoTShieldBonus = mq.TLO.Me.DoTShieldBonus() or 0
    data.Doubloons = mq.TLO.Me.Doubloons() or 0
    data.Downtime = mq.TLO.Me.Downtime() or 0
    data.Drunk = mq.TLO.Me.Drunk() or 0
    data.EbonCrystals = mq.TLO.Me.EbonCrystals() or 0
    data.EnduranceBonus = mq.TLO.Me.EnduranceBonus() or 0
    data.EnduranceRegen = mq.TLO.Me.EnduranceRegen() or 0
    data.EnduranceRegenBonus = mq.TLO.Me.EnduranceRegenBonus() or 0
    data.Exp = mq.TLO.Me.Exp() or 0
    data.ExpansionFlags = mq.TLO.Me.ExpansionFlags() or 0
    data.Faycites = mq.TLO.Me.Faycites() or 0
    data.Feared = mq.TLO.Me.Feared() or "None"
    data.Fellowship = mq.TLO.Me.Fellowship() == "TRUE" or false
    data.FreeBuffSlots = mq.TLO.Me.FreeBuffSlots() or 0
    data.FeetWet = mq.TLO.Me.FeetWet()
    data.HeadWet = mq.TLO.Me.HeadWet()
    data.Swimming = (mq.TLO.Me.FeetWet() and mq.TLO.Me.HeadWet()) or false
    data.Gold = mq.TLO.Me.Gold() or 0
    data.GoldBank = mq.TLO.Me.GoldBank() or 0
    data.GroupAssistTarget = mq.TLO.Me.GroupAssistTarget() and mq.TLO.Me.GroupAssistTarget.CleanName() or "None"
    data.Grouped = mq.TLO.Me.Grouped()
    data.GroupLeader = mq.TLO.Group.Leader() and mq.TLO.Group.Leader.CleanName() or "None"
    data.GroupLeaderExp = mq.TLO.Me.GroupLeaderExp() or 0
    data.GroupLeaderPoints = mq.TLO.Me.GroupLeaderPoints() or 0
    data.GroupSize = mq.TLO.Me.GroupSize() or 0
    data.GukEarned = mq.TLO.Me.GukEarned() or 0
    data.Guild = mq.TLO.Me.Guild() or "NO GUILD"
    data.GuildID = mq.TLO.Me.GuildID() or 0
    data.Haste = mq.TLO.Me.Haste() or 0
    data.HealAmountBonus = mq.TLO.Me.HealAmountBonus() or 0
    data.HeroicAGIBonus = mq.TLO.Me.HeroicAGIBonus() or 0
    data.HeroicCHABonus = mq.TLO.Me.HeroicCHABonus() or 0
    data.HeroicDEXBonus = mq.TLO.Me.HeroicDEXBonus() or 0
    data.HeroicINTBonus = mq.TLO.Me.HeroicINTBonus() or 0
    data.HeroicSTABonus = mq.TLO.Me.HeroicSTABonus() or 0
    data.HeroicSTRBonus = mq.TLO.Me.HeroicSTRBonus() or 0
    data.HeroicWISBonus = mq.TLO.Me.HeroicWISBonus() or 0
    data.Hidden = mq.TLO.Me.Invis(4)
    data.HPBonus = mq.TLO.Me.HPBonus() or 0
    data.HPRegen = mq.TLO.Me.HPRegen() or 0
    data.HPRegenBonus = mq.TLO.Me.HPRegenBonus() or 0
    data.Hunger = mq.TLO.Me.Hunger() or 0
    data.ID = mq.TLO.Me.ID() or 0
    data.InInstance = mq.TLO.Me.InInstance()
    data.Instance = mq.TLO.Me.Instance() or 0
    data.Invis = mq.TLO.Me.Invis()
    data.InvisAnimal = mq.TLO.Me.Invis(3)
    data.InvisUndead = mq.TLO.Me.Invis(2)
    data.INT = mq.TLO.Me.INT() or 0
    data.Invulnerable = mq.TLO.Me.Invulnerable() or "None"
    data.LADelegateMA = mq.TLO.Me.LADelegateMA() or 0
    data.LADelegateMarkNPC = mq.TLO.Me.LADelegateMarkNPC() or 0
    data.LAFindPathPC = mq.TLO.Me.LAFindPathPC() or 0
    data.LAHealthEnhancement = mq.TLO.Me.LAHealthEnhancement() or 0
    data.LAHealthRegen = mq.TLO.Me.LAHealthRegen() or 0
    data.LAHoTT = mq.TLO.Me.LAHoTT() or 0
    data.LAInspectBuffs = mq.TLO.Me.LAInspectBuffs() or 0
    data.LAManaEnhancement = mq.TLO.Me.LAManaEnhancement() or 0
    data.LAMarkNPC = mq.TLO.Me.LAMarkNPC() or 0
    data.LANPCHealth = mq.TLO.Me.LANPCHealth() or 0
    data.LAOffenseEnhancement = mq.TLO.Me.LAOffenseEnhancement() or 0
    data.LASpellAwareness = mq.TLO.Me.LASpellAwareness() or 0
    data.LargestFreeInventory = mq.TLO.Me.LargestFreeInventory() or 0
    data.LastZoned = mq.TLO.Me.LastZoned() or 0
    data.LDoNPoints = mq.TLO.Me.LDoNPoints() or 0
    data.Level = mq.TLO.Me.Level() or 0
    data.ManaBonus = mq.TLO.Me.ManaBonus() or 0
    data.ManaRegen = mq.TLO.Me.ManaRegen() or 0
    data.ManaRegenBonus = mq.TLO.Me.ManaRegenBonus() or 0
    data.MaxBuffSlots = mq.TLO.Me.MaxBuffSlots() or 0
    data.MaxEndurance = mq.TLO.Me.MaxEndurance() or 0
    data.MaxHPs = mq.TLO.Me.MaxHPs() or 0
    data.MaxMana = mq.TLO.Me.MaxMana() or 0
    data.Mercenary = mq.TLO.Me.Mercenary() or "None"
    data.MercenaryStance = mq.TLO.Me.MercenaryStance() or "None"
    data.Mezzed = mq.TLO.Me.Mezzed() or "None"
    data.MirEarned = mq.TLO.Me.MirEarned() or 0
    data.MMEarned = mq.TLO.Me.MMEarned() or 0
    data.Moving = mq.TLO.Me.Moving()
    data.Name = mq.TLO.Me.Name() or "None"
    data.NumGems = mq.TLO.Me.NumGems() or 0
    data.NumBagSlots = mq.TLO.Me.NumBagSlots() or 0
    data.Origin = mq.TLO.Me.Origin() or "None"
    data.Orux = mq.TLO.Me.Orux() or 0
    data.Pet = mq.TLO.Pet() and mq.TLO.Pet.Name() or "NO PET"
    data.PctAAExp = mq.TLO.Me.PctAAExp() or 0
    data.PctAAVitality = mq.TLO.Me.PctAAVitality() or 0
    data.PctAirSupply = mq.TLO.Me.PctAirSupply() or 0
    data.PctAggro = mq.TLO.Me.PctAggro() or 0
    data.PctEndurance = mq.TLO.Me.PctEndurance() or 0
    data.PctExp = mq.TLO.Me.PctExp() or 0
    data.PctGroupLeaderExp = mq.TLO.Me.PctGroupLeaderExp() or 0
    data.PctHPs = mq.TLO.Me.PctHPs() or 0
    data.PctMana = mq.TLO.Me.PctMana() or 0
    data.PctRaidLeaderExp = mq.TLO.Me.PctRaidLeaderExp() or 0
    data.PctVitality = mq.TLO.Me.PctVitality() or 0
    data.Phosphenes = mq.TLO.Me.Phosphenes() or 0
    data.Phosphites = mq.TLO.Me.Phosphites() or 0
    data.Platinum = mq.TLO.Me.Platinum() or 0
    data.PlatinumBank = mq.TLO.Me.PlatinumBank() or 0
    data.PlatinumShared = mq.TLO.Me.PlatinumShared() or 0
    data.Poisoned = mq.TLO.Me.Poisoned() or "None"
    data.RadiantCrystals = mq.TLO.Me.RadiantCrystals() or 0
    data.RaidLeader = mq.TLO.Raid.Leader() and mq.TLO.Raid.Leader.CleanName() or "None"
    data.RaidLeaderExp = mq.TLO.Me.RaidLeaderExp() or 0
    data.RaidLeaderPoints = mq.TLO.Me.RaidLeaderPoints() or 0
    data.RaidSize = mq.TLO.Raid.Members() or 0
    data.RangedReady = mq.TLO.Me.RangedReady()
    data.Rooted = mq.TLO.Me.Rooted() or "None"
    data.RujEarned = mq.TLO.Me.RujEarned() or 0
    data.Running = mq.TLO.Me.Running()
    data.SecondaryPctAggro = mq.TLO.Me.SecondaryPctAggro() or 0
    data.SecondaryAggroPlayer = mq.TLO.Me.SecondaryAggroPlayer() and mq.TLO.Me.SecondaryAggroPlayer.CleanName() or "None"
    data.ShieldingBonus = mq.TLO.Me.ShieldingBonus() or 0
    data.Shrouded = mq.TLO.Me.Shrouded()
    data.Silenced = mq.TLO.Me.Silenced() or "None"
    data.Silver = mq.TLO.Me.Silver() or 0
    data.SilverBank = mq.TLO.Me.SilverBank() or 0
    data.Sitting = mq.TLO.Me.Sitting()
    data.Snared = mq.TLO.Me.Snared() or "None"
    data.Sneaking = mq.TLO.Me.Sneaking()
    data.Speed = mq.TLO.Me.Speed() or 0
    data.SpellInCooldown = mq.TLO.Me.SpellInCooldown()
    data.SpellDamageBonus = mq.TLO.Me.SpellDamageBonus() or 0
    data.SpellRankCap = mq.TLO.Me.SpellRankCap() or 0
    data.SpellShieldBonus = mq.TLO.Me.SpellShieldBonus() or 0
    data.STA = mq.TLO.Me.STA() or 0
    data.Standing = mq.TLO.Me.Standing()
    -- data.StopCast = mq.TLO.Me.StopCast()
    data.STR = mq.TLO.Me.STR() or 0
    data.StrikeThroughBonus = mq.TLO.Me.StrikeThroughBonus() or 0
    data.Stunned = mq.TLO.Me.Stunned()
    data.StunResistBonus = mq.TLO.Me.StunResistBonus() or 0
    data.Subscription = mq.TLO.Me.Subscription() or "None"
    data.SubscriptionDays = mq.TLO.Me.SubscriptionDays() or 0
    data.Surname = mq.TLO.Me.Surname() or "None"
    data.svChromatic = mq.TLO.Me.svChromatic() or 0
    data.svCold = mq.TLO.Me.svCold() or 0
    data.svCorruption = mq.TLO.Me.svCorruption() or 0
    data.svDisease = mq.TLO.Me.svDisease() or 0
    data.svFire = mq.TLO.Me.svFire() or 0
    data.svMagic = mq.TLO.Me.svMagic() or 0
    data.svPoison = mq.TLO.Me.svPoison() or 0
    data.svPrismatic = mq.TLO.Me.svPrismatic() or 0
    data.TakEarned = mq.TLO.Me.TakEarned() or 0
    data.TargetID = mq.TLO.Target() and mq.TLO.Target.ID() or 0
    data.TargetName = mq.TLO.Target() and mq.TLO.Target.CleanName() or "None"
    data.TargetOfTarget = mq.TLO.Me.TargetOfTarget() and mq.TLO.Me.TargetOfTarget.CleanName() or "None"
    data.Tashed = mq.TLO.Me.Tashed() or "None"
    data.Thirst = mq.TLO.Me.Thirst() or 0
    data.TotalCounters = mq.TLO.Me.TotalCounters() or 0
    data.Trader = mq.TLO.Me.Trader()
    data.TributeActive = mq.TLO.Me.TributeActive()
    data.TributeTimer = mq.TLO.Me.TributeTimer() or 0
    data.UseAdvancedLooting = mq.TLO.Me.UseAdvancedLooting()
    data.WIS = mq.TLO.Me.WIS() or 0
    data.Vitality = mq.TLO.Me.Vitality() or 0
    data.XTargetSlots = mq.TLO.Me.XTargetSlots() or 0
    data.X = mq.TLO.Me.X() or 0
    data.Y = mq.TLO.Me.Y() or 0
    data.Z = mq.TLO.Me.Z() or 0
    data.ZoneBound = mq.TLO.Me.ZoneBound() or "None"
    data.ZoneBoundX = mq.TLO.Me.ZoneBoundX() or 0
    data.ZoneBoundY = mq.TLO.Me.ZoneBoundY() or 0
    data.ZoneBoundZ = mq.TLO.Me.ZoneBoundZ() or 0
    data.Zoning = mq.TLO.Me.Zoning()
    data.Zone = mq.TLO.Zone.Name() or "None"

    return data
end

--- Get Song Information for a given Slot
--- If the slot is empty, fill default data into the table and return false
--- Otherwise update the data and return true
--- @param slot integer
--- @return boolean
local function GetSong(slot)
    if not slot then return false end
    local songTooltip, songName, songDurationDisplay, songIcon, songID, songBeneficial, songHr, songMin, songSec, totalMin, totalSec, songDurHMS
    local song = mq.TLO.Me.Song(slot)
    if song() == nil then
        SongTable[slot] = {
            Name = '',
            Beneficial = true,
            Duration = '',
            DurationDisplay = '',
            Icon = 0,
            ID = 0,
            Slot = slot,
            Hours = 0,
            Minutes = 0,
            Seconds = 0,
            TotalMinutes = 0,
            TotalSeconds = 0,
            Tooltip = '',
        }
        return false
    end


    local duration = song.Duration
    songName = song.Name() or ''
    songIcon = song.SpellIcon() or 0
    songID = song.Spell.ID() or 0
    songBeneficial = song.Beneficial() or false

    songDurHMS = duration.TimeHMS() or ''
    songHr = duration.Hours() or 0
    songMin = duration.Minutes() or 0
    songSec = duration.Seconds() or 0
    -- format tooltip
    songHr = songHr and string.format("%02d", tonumber(songHr)) or "00"
    songMin = songMin and string.format("%02d", tonumber(songMin)) or "00"
    songSec = songSec and string.format("%02d", tonumber(songSec)) or "00"
    songDurationDisplay = string.format("%s:%s:%s", songHr, songMin, songSec)

    songTooltip = string.format("%s) %s (%s)", slot, songName, songDurHMS)

    SongTable[slot] = {
        Name = songName,
        Beneficial = songBeneficial,
        Duration = songDurHMS,
        DurationDisplay = songDurationDisplay,
        Icon = songIcon,
        ID = songID,
        Slot = slot,
        Hours = songHr,
        Minutes = songMin,
        Seconds = songSec,
        TotalMinutes = totalMin,
        TotalSeconds = totalSec,
        Tooltip = songTooltip,
    }
    return true
end


--- Get Buff Information for a specified slot.
--- If the slot is empty, insert default data into the table for the slot and return false.
--- If the slot has a buff, update the Data and return true.
---@return boolean
function CharData.GetBuff(slot)
    local buffTooltip, buffName, buffDurDisplay, buffIcon, buffID, buffBeneficial, buffHr, buffMin, buffSec, totalMin, totalSec, buffDurHMS
    local buff = mq.TLO.Me.Buff(slot)
    if buff() == nil then
        BuffTable[slot] = {
            Name = '',
            Beneficial = true,
            Duration = '',
            DurationDisplay = '',
            Icon = 0,
            ID = 0,
            Slot = slot,
            Hours = 0,
            Minutes = 0,
            Seconds = 0,
            TotalMinutes = 0,
            TotalSeconds = 0,
            Tooltip = "",
        }
        return false
    end

    local duration = buff.Duration

    buffName = buff.Name() or ''
    buffIcon = buff.SpellIcon() or 0
    buffID = buff.Spell.ID() or 0
    buffBeneficial = buff.Beneficial() or false

    -- Extract hours, minutes, and seconds from buffDuration
    buffHr = duration.Hours() or 0
    buffMin = duration.Minutes() or 0
    buffSec = duration.Seconds() or 0

    -- Calculate total minutes and total seconds
    totalMin = duration.TotalMinutes() or 0
    totalSec = duration.TotalSeconds() or 0
    -- Utils.PrintOutput('MyUI',nil,totalSec)
    buffDurHMS = duration.TimeHMS() or ''

    -- format tooltip

    local dispBuffHr = buffHr and string.format("%02d", buffHr) or "00"
    local displayBuffMin = buffMin and string.format("%02d", buffMin) or "00"
    local displayBuffSec = buffSec and string.format("%02d", buffSec) or "00"
    buffDurDisplay = string.format("%s:%s:%s", dispBuffHr, displayBuffMin, displayBuffSec)
    buffTooltip = string.format("%s) %s (%s)", slot, buffName, buffDurHMS)

    if BuffTable[slot] ~= nil then
        if BuffTable[slot].ID ~= buffID or os.time() - CheckIn >= 6 then
            Changed = true
        end
    end

    if not buffBeneficial then
        if #DebuffOnMe > 0 then
            local found = false
            for i = 1, #DebuffOnMe do
                if DebuffOnMe[i].ID == buffID then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(DebuffOnMe, {
                    Name = buffName,
                    Duration = buffDurHMS,
                    DurationDisplay = buffDurDisplay,
                    Icon = buffIcon,
                    ID = buffID,
                    Hours = buffHr,
                    Slot = slot,
                    Minutes = buffMin,
                    Seconds = buffSec,
                    TotalMinutes = totalMin,
                    TotalSeconds = totalSec,
                    Tooltip = buffTooltip,
                })
            end
        else
            table.insert(DebuffOnMe, {
                Name = buffName,
                Duration = buffDurHMS,
                DurationDisplay = buffDurDisplay,
                Icon = buffIcon,
                ID = buffID,
                Hours = buffHr,
                Slot = slot,
                Minutes = buffMin,
                Seconds = buffSec,
                TotalMinutes = totalMin,
                TotalSeconds = totalSec,
                Tooltip = buffTooltip,
            })
        end
    end

    BuffTable[slot] = {
        Name = buffName,
        Beneficial = buffBeneficial,
        Duration = buffDurHMS,
        DurationDisplay = buffDurDisplay,
        Icon = buffIcon,
        ID = buffID,
        Slot = slot,
        Hours = buffHr,
        Minutes = buffMin,
        Seconds = buffSec,
        TotalMinutes = totalMin,
        TotalSeconds = totalSec,
        Tooltip = buffTooltip,
    }
    -- MyBuffsNames[buffName] = true

    return true
end

--- Get Buffs and return Buffs and Defbuffs tables.
--- Buffs table is all buffs and debuffs while Debuffs is only debuffs
---@return table BuffTable
---@return table DebuffOnMe
function CharData.GetBuffs()
    DebuffOnMe = {}
    numBuffs = 0
    numSlots = mq.TLO.Me.MaxBuffSlots() or 0
    if numSlots == 0 then
        BuffTable = {}
        return BuffTable, DebuffOnMe
    end -- most likely not loaded all the way try again next cycle
    for i = 1, numSlots do
        local hasBuff = false
        hasBuff = CharData.GetBuff(i)
        if hasBuff then
            numBuffs = numBuffs + 1
        end
    end

    return BuffTable, DebuffOnMe
end

--- Get Songs and return a table of songs
--- Songs table is indexed by slot number
---@return table SongTable
function CharData.GetSongs()
    if mq.TLO.Me.CountSongs() > 0 then
        for i = 1, MAX_SONGS do
            GetSong(i)
        end
    end
    return SongTable
end

--- Get Button States for pet commands
---@return table btnInfo
local function GetButtonStates()
    local stance = myPet.Stance() or "UNKNOWN"
    btnInfo.follow = stance == 'FOLLOW' and true or false
    btnInfo.guard = stance == 'GUARD' and true or false
    btnInfo.sit = myPet.Sitting() and true or false
    btnInfo.taunt = myPet.Taunt() and true or false
    btnInfo.stop = myPet.Stop() and true or false
    btnInfo.hold = myPet.Hold() and true or false
    btnInfo.focus = myPet.Focus() and true or false
    btnInfo.regroup = myPet.ReGroup() and true or false
    btnInfo.ghold = myPet.GHold() and true or false
    return btnInfo
end

--- Get Pet Data and return a table with pet information
--- Pet data includes ID, Name, Type, Level, PctHPs, Distance, BuffCount, and Buffs
---@return table petStatus (sub tables ButtonStates, and Buffs)
---@return integer tmpBuffCnt # of buffs on pet`
function CharData.GetPetData()
    local petStatus = {}
    petStatus.ID = myPet.ID() or 0
    petStatus.Name = myPet.DisplayName() or "None"
    petStatus.Type = myPet.Type() or "None"
    petStatus.Level = myPet.Level() or 0
    petStatus.PctHPs = myPet.PctHPs() or 0
    petStatus.Distance = myPet.Distance() or 0
    petStatus.BuffCount = myPet.BuffCount() or 0

    local petBuffTable = {}
    if myPet() == 'NO PET' then
        return petBuffTable, 0
    end

    local petBuffCount = 0
    for i = 1, MAX_PET_BUFFS do
        local buff = myPet.Buff(i)
        local name = buff() or 'None'
        local id = buff.ID() or 0
        local beneficial = buff.Beneficial() or false
        local icon = buff.SpellIcon() or 0
        local slot = i
        petBuffTable[i] = {}
        petBuffTable[i] = { Name = name, ID = id, Beneficial = beneficial, Icon = icon, Slot = slot, }
        if name ~= 'None' then
            petBuffCount = petBuffCount + 1
        end
        if petBuffCount >= petStatus.BuffCount then
            break
        end
    end

    petStatus.Buffs = petBuffTable
    petStatus.ButtonStates = GetButtonStates()

    return petStatus, petStatus.BuffCount
end

--- Retreives all data and returns it in a single nested table
function CharData.GetAllData()
    local dataTable = {}
    dataTable = CharData.GetMyData()
    dataTable.Buffs, dataTable.Debuffs = CharData.GetBuffs()
    dataTable.Songs = CharData.GetSongs()
    dataTable.PetData, dataTable.PetBuffCount = CharData.GetPetData()
    return dataTable
end

return CharData
