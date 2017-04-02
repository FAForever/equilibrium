-- ****************************************************************************
-- **
-- **  File     :  /cdimage/units/URL0301/URL0301_script.lua
-- **  Author(s):  David Tomandl, Jessica St. Croix
-- **
-- **  Summary  :  Cybran Sub Commander Script
-- **
-- **  Copyright Š 2005 Gas Powered Games, Inc.  All rights reserved.
-- ****************************************************************************
local CCommandUnit = import('/lua/cybranunits.lua').CCommandUnit
local CWeapons = import('/lua/cybranweapons.lua')
local EffectUtil = import('/lua/EffectUtilities.lua')
local Buff = import('/lua/sim/Buff.lua')

local CAAMissileNaniteWeapon = CWeapons.CAAMissileNaniteWeapon
local CDFLaserDisintegratorWeapon = CWeapons.CDFLaserDisintegratorWeapon02
local SCUDeathWeapon = import('/lua/sim/defaultweapons.lua').SCUDeathWeapon

URL0301 = Class(CCommandUnit) {
    LeftFoot = 'Left_Foot02',
    RightFoot = 'Right_Foot02',

    Weapons = {
        DeathWeapon = Class(SCUDeathWeapon) {},
        RightDisintegrator = Class(CDFLaserDisintegratorWeapon) {
            OnCreate = function(self)
                CDFLaserDisintegratorWeapon.OnCreate(self)
                -- Disable buff
                self:DisableBuff('STUN')
            end,
        },
        NMissile = Class(CAAMissileNaniteWeapon) {},
    },

    -- ********
    -- Creation
    -- ********
    OnCreate = function(self)
        CCommandUnit.OnCreate(self)
        self:SetCapturable(false)
        self:HideBone('AA_Gun', true)
        self:HideBone('Power_Pack', true)
        self:HideBone('Rez_Protocol', true)
        self:HideBone('Torpedo', true)
        self:HideBone('Turbine', true)
        self:SetWeaponEnabledByLabel('NMissile', false)
        if self:GetBlueprint().General.BuildBones then
            self:SetupBuildBones()
        end
        self.IntelButtonSet = true
    end,

    __init = function(self)
        CCommandUnit.__init(self, 'RightDisintegrator')
    end,

    -- ********
    -- Engineering effects
    -- ********
    CreateBuildEffects = function( self, unitBeingBuilt, order )
       EffectUtil.SpawnBuildBots( self, unitBeingBuilt, self.BuildEffectsBag )
       EffectUtil.CreateCybranBuildBeams( self, unitBeingBuilt, self:GetBlueprint().General.BuildBones.BuildEffectBones, self.BuildEffectsBag )
    end,

    OnStopBeingBuilt = function(self,builder,layer)
        CCommandUnit.OnStopBeingBuilt(self,builder,layer)
        self:BuildManipulatorSetEnabled(false)
        self:SetMaintenanceConsumptionInactive()
        -- Disable enhancement-based Intels until enhancements are built
        self:DisableUnitIntel('Enhancement', 'RadarStealthField') -- changed to field in equilibrium
        self:DisableUnitIntel('Enhancement', 'SonarStealthField') -- changed to field in equilibrium
        self:DisableUnitIntel('Enhancement', 'Cloak')
        self.LeftArmUpgrade = 'EngineeringArm'
        self.RightArmUpgrade = 'Disintegrator'
    end,

    -- ************
    -- Enhancements
    -- ************
    CreateEnhancement = function(self, enh)
        CCommandUnit.CreateEnhancement(self, enh)
        local bp = self:GetBlueprint().Enhancements[enh]
        if not bp then return end
        if enh == 'CloakingGenerator' then
            self.StealthEnh = false
			self.CloakEnh = true
            self:EnableUnitIntel('Enhancement', 'Cloak')
            if not Buffs['CybranSCUCloakBonus'] then
               BuffBlueprint {
                    Name = 'CybranSCUCloakBonus',
                    DisplayName = 'CybranSCUCloakBonus',
                    BuffType = 'SCUCLOAKBONUS',
                    Stacks = 'ALWAYS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                    },
                }
            end
            if Buff.HasBuff( self, 'CybranSCUCloakBonus' ) then
                Buff.RemoveBuff( self, 'CybranSCUCloakBonus' )
            end
            Buff.ApplyBuff(self, 'CybranSCUCloakBonus')
        elseif enh == 'CloakingGeneratorRemove' then
            self:DisableUnitIntel('Enhancement', 'Cloak')
            self.StealthEnh = false
            self.CloakEnh = false
            self:RemoveToggleCap('RULEUTC_CloakToggle')
            if Buff.HasBuff( self, 'CybranSCUCloakBonus' ) then
                Buff.RemoveBuff( self, 'CybranSCUCloakBonus' )
            end
        elseif enh == 'StealthGenerator' then
            self:AddToggleCap('RULEUTC_CloakToggle')
            if self.IntelEffectsBag then
                EffectUtil.CleanupEffectBag(self,'IntelEffectsBag')
                self.IntelEffectsBag = nil
            end
            self.CloakEnh = false
            self.StealthEnh = true
            self:EnableUnitIntel('Enhancement', 'RadarStealthField') -- added by ithilis
            self:EnableUnitIntel('Enhancement', 'SonarStealthField') -- added by ithilis
        elseif enh == 'StealthGeneratorRemove' then
            self:RemoveToggleCap('RULEUTC_CloakToggle')
            self:DisableUnitIntel('Enhancement', 'RadarStealthField') -- added by ithilis
            self:DisableUnitIntel('Enhancement', 'SonarStealthField') -- added by ithilis
            self.StealthEnh = false
            self.CloakEnh = false
        elseif enh == 'NaniteMissileSystem' then
            self:ShowBone('AA_Gun', true)
            self:SetWeaponEnabledByLabel('NMissile', true)
        elseif enh == 'NaniteMissileSystemRemove' then
            self:HideBone('AA_Gun', true)
            self:SetWeaponEnabledByLabel('NMissile', false)
        elseif enh == 'SelfRepairSystem' then
            -- added by brute51 - fix for bug SCU regen upgrade doesnt stack with veteran bonus [140]
            CCommandUnit.CreateEnhancement(self, enh)
            local bpRegenRate = self:GetBlueprint().Enhancements.SelfRepairSystem.NewRegenRate or 0
            if not Buffs['CybranSCURegenerateBonus'] then
               BuffBlueprint {
                    Name = 'CybranSCURegenerateBonus',
                    DisplayName = 'CybranSCURegenerateBonus',
                    BuffType = 'SCUREGENERATEBONUS',
                    Stacks = 'ALWAYS',
                    Duration = -1,
                    Affects = {
                        Regen = {
                            Add = bpRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            if Buff.HasBuff( self, 'CybranSCURegenerateBonus' ) then
                Buff.RemoveBuff( self, 'CybranSCURegenerateBonus' )
            end
            Buff.ApplyBuff(self, 'CybranSCURegenerateBonus')
        elseif enh == 'SelfRepairSystemRemove' then
            -- added by brute51 - fix for bug SCU regen upgrade doesnt stack with veteran bonus [140]
            CCommandUnit.CreateEnhancement(self, enh)
            if Buff.HasBuff( self, 'CybranSCURegenerateBonus' ) then
                Buff.RemoveBuff( self, 'CybranSCURegenerateBonus' )
            end
        elseif enh =='ResourceAllocation' then
            local bpEcon = self:GetBlueprint().Economy
            self:SetProductionPerSecondEnergy(bp.ProductionPerSecondEnergy + bpEcon.ProductionPerSecondEnergy or 0)
            self:SetProductionPerSecondMass(bp.ProductionPerSecondMass + bpEcon.ProductionPerSecondMass or 0)
            self.NewDeathDamage = bp.NewDeathDamage --insert our new death damage value into our unit table
            --this will be picked up by DoDeathWeapon in unit.lua and replace the blueprint value.
        elseif enh == 'ResourceAllocationRemove' then
            local bpEcon = self:GetBlueprint().Economy
            self:SetProductionPerSecondEnergy(bpEcon.ProductionPerSecondEnergy or 0)
            self:SetProductionPerSecondMass(bpEcon.ProductionPerSecondMass or 0)
            self.NewDeathDamage = (bp.NewDeathDamage or 2500)
            --we dont use self:GetBlueprint().Weapon[2].Damage because thats set to 5000 for some reason
        elseif enh =='Switchback' then
            if not Buffs['CybranSCUBuildRate'] then
                BuffBlueprint {
                    Name = 'CybranSCUBuildRate',
                    DisplayName = 'CybranSCUBuildRate',
                    BuffType = 'SCUBUILDRATE',
                    Stacks = 'REPLACE',
                    Duration = -1,
                    Affects = {
                        BuildRate = {
                            Add =  bp.NewBuildRate - self:GetBlueprint().Economy.BuildRate,
                            Mult = 1,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranSCUBuildRate')
        elseif enh == 'SwitchbackRemove' then
            if Buff.HasBuff( self, 'CybranSCUBuildRate' ) then
                Buff.RemoveBuff( self, 'CybranSCUBuildRate' )
            end

--Fixed damage stacking infinitely and range not being reduced on removal (IceDreamer)
        elseif enh == 'FocusConvertor' then
            local wep = self:GetWeaponByLabel('RightDisintegrator')
            wep:AddDamageMod(bp.NewDamageMod or 0)
            wep:ChangeMaxRadius(bp.NewMaxRadius or 35)
            wep:AddDamageRadiusMod(bp.NewDamageRadius)        --ADD by itilis
        elseif enh == 'FocusConvertorRemove' then
            local wep = self:GetWeaponByLabel('RightDisintegrator')
            wep:AddDamageMod(-self:GetBlueprint().Enhancements['FocusConvertor'].NewDamageMod)
            wep:ChangeMaxRadius(self:GetBlueprint().Weapon[1].MaxRadius or 25)
            wep:AddDamageRadiusMod(-self:GetBlueprint().Enhancements['FocusConvertor'].NewDamageRadius)        --add by ihtilis ----------------------------------------------------- what the fuck xD
        elseif enh == 'EMPCharge' then
            local wep = self:GetWeaponByLabel('RightDisintegrator')
            wep:ReEnableBuff('STUN')
        elseif enh == 'EMPChargeRemove' then
            local wep = self:GetWeaponByLabel('RightDisintegrator')
            wep:DisableBuff('STUN')
        end
        self:AdjustPriceOnEnh() --EQ: we adjust our sacus price when we get or lose an enhancement
    end,

    AdjustPriceOnEnh = function(self)
        -- change cost of the new unit to match unit base cost + enhancement costs.
        
        local bp = self:GetBlueprint()
        
        -- In the case of presets, use the base bp for prices. and stuff.
        if bp.EnhancementPresetAssigned.BaseBlueprintId then
            bp = GetUnitBlueprintByName(bp.EnhancementPresetAssigned.BaseBlueprintId)
        end
        
        local e, m, t = 0, 0, 0
        
        local enhCommon = import('/lua/enhancementcommon.lua') --get our unit enhs
        local unitEnhancements = enhCommon.GetEnhancements(self:GetEntityId())
        
        if unitEnhancements then --If we have no enh this is a nil value, so we bail
            for k, enh in unitEnhancements do
                -- replaced continue by reversing if statement
                if bp.Enhancements[enh] then
                    e = e + (bp.Enhancements[enh].BuildCostEnergy or 0)
                    m = m + (bp.Enhancements[enh].BuildCostMass or 0)
                    t = t + (bp.Enhancements[enh].BuildTime or 0)
                    -- HUSSAR added name of the enhancement so that preset units cannot be built
                end
            end
        end
        
        --add our enh costs onto our base costs.
        self.BuildCostM = bp.Economy.BuildCostMass + m
        self.BuildCostE = bp.Economy.BuildCostEnergy + e
        self.BuildT = bp.Economy.BuildTime + t
        
        --WARN('enhancement mass/energy/time: ' .. m .. ', ' .. e .. ', ' .. t)
        --WARN('total mass/energy/time: ' .. self.BuildCostM .. ', ' .. self.BuildCostE .. ', ' .. self.BuildT)
    end,

    CreateWreckageProp = function( self, overkillRatio )
    --intercept the wreckage creation code so it changes the wreckage value as well. we just pass a modified overkill multiplier for that.
        local bp = self:GetBlueprint()
        
        local adjustedOKRMass = ((bp.Economy.BuildCostMass - self.BuildCostM) / bp.Economy.BuildCostMass) + (overkillRatio or 1)
        --WARN('regular reclaim value: '..bp.Economy.BuildCostMass*0.81 .. ' adjusted reclaim value: '..self.BuildCostM*0.81)
        CCommandUnit.CreateWreckageProp(self, adjustedOKRMass)
    end,

    -- *****
    -- Death
    -- *****
    OnKilled = function(self, instigator, type, overkillRatio)
        local bp
        for k, v in self:GetBlueprint().Buffs do
            if v.Add.OnDeath then
                bp = v
            end
        end
        -- if we could find a blueprint with v.Add.OnDeath, then add the buff
        if bp ~= nil then
            -- Apply Buff
			self:AddBuff(bp)
        end
        -- otherwise, we should finish killing the unit
        CCommandUnit.OnKilled(self, instigator, type, overkillRatio)
    end,

    IntelEffects = {
		Cloak = {
		    {
			    Bones = {
				    'Head',
				    'Right_Elbow',
				    'Left_Elbow',
				    'Right_Arm01',
				    'Left_Shoulder',
				    'Torso',
				    'URL0301',
				    'Left_Thigh',
				    'Left_Knee',
				    'Left_Leg',
				    'Right_Thigh',
				    'Right_Knee',
				    'Right_Leg',
			    },
			    Scale = 1.0,
			    Type = 'Cloak01',
		    },
		},
		Field = {
		    {
			    Bones = {
				    'Head',
				    'Right_Elbow',
				    'Left_Elbow',
				    'Right_Arm01',
				    'Left_Shoulder',
				    'Torso',
				    'URL0301',
				    'Left_Thigh',
				    'Left_Knee',
				    'Left_Leg',
				    'Right_Thigh',
				    'Right_Knee',
				    'Right_Leg',
			    },
			    Scale = 1.6,
			    Type = 'Cloak01',
		    },
        },
    },

    OnIntelEnabled = function(self)
        CCommandUnit.OnIntelEnabled(self)
        if self.CloakEnh and self:IsIntelEnabled('Cloak') then
            self:SetEnergyMaintenanceConsumptionOverride(self:GetBlueprint().Enhancements['CloakingGenerator'].MaintenanceConsumptionPerSecondEnergy or 0)
            self:SetMaintenanceConsumptionActive()
            if not self.IntelEffectsBag then
			    self.IntelEffectsBag = {}
			    self.CreateTerrainTypeEffects( self, self.IntelEffects.Cloak, 'FXIdle',  self:GetCurrentLayer(), nil, self.IntelEffectsBag )
			end
        elseif self.StealthEnh and self:IsIntelEnabled('RadarStealthField') and self:IsIntelEnabled('SonarStealthField') then
            self:SetEnergyMaintenanceConsumptionOverride(self:GetBlueprint().Enhancements['StealthGenerator'].MaintenanceConsumptionPerSecondEnergy or 0)
            self:SetMaintenanceConsumptionActive()
            if not self.IntelEffectsBag then
	            self.IntelEffectsBag = {}
		        self.CreateTerrainTypeEffects( self, self.IntelEffects.Field, 'FXIdle',  self:GetCurrentLayer(), nil, self.IntelEffectsBag )
		    end
        end
    end,

    OnIntelDisabled = function(self)
        CCommandUnit.OnIntelDisabled(self)
        if self.IntelEffectsBag then
            EffectUtil.CleanupEffectBag(self,'IntelEffectsBag')
            self.IntelEffectsBag = nil
        end
        if self.CloakEnh and not self:IsIntelEnabled('Cloak') then
            self:SetMaintenanceConsumptionInactive()
        elseif self.StealthEnh and not self:IsIntelEnabled('RadarStealth') and not self:IsIntelEnabled('SonarStealth') then
            self:SetMaintenanceConsumptionInactive()
        end
    end
}

TypeClass = URL0301




























