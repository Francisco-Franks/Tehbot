/*

Tehbot  Copyright � 2012  Tehtsuo and Vendan

This file is part of Tehbot.

Tehbot is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Tehbot is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Tehbot.  If not, see <http://www.gnu.org/licenses/>.

*/

objectdef obj_Configuration_AutoModule inherits obj_Configuration_Base
{
	method Initialize()
	{
		This[parent]:Initialize["AutoModule"]
	}

	method Set_Default_Values()
	{
		ConfigManager.ConfigRoot:AddSet[${This.SetName}]
		This.ConfigRef:AddSetting[ActiveHardeners, TRUE]
		This.ConfigRef:AddSetting[ActiveShieldBoost, 95]
		This.ConfigRef:AddSetting[ActiveArmorRepair, 95]
		This.ConfigRef:AddSetting[ActiveShieldCap, 35]
		This.ConfigRef:AddSetting[ActiveArmorCap, 35]
		This.ConfigRef:AddSetting[Cloak, TRUE]
		This.ConfigRef:AddSetting[GangLink, TRUE]
		This.ConfigRef:AddSetting[SensorBoosters, TRUE]
		This.ConfigRef:AddSetting[AutoTarget, TRUE]
		This.ConfigRef:AddSetting[TrackingComputers, TRUE]
		This.ConfigRef:AddSetting[ECCM, TRUE]
		This.ConfigRef:AddSetting[DroneControlUnit, TRUE]
		This.ConfigRef:AddSetting[ShieldBoostOverloadThreshold, 50]
		This.ConfigRef:AddSetting[ArmorRepairOverloadThreshold, 50]
	}

	Setting(bool, ActiveHardeners, SetActiveHardeners)
	Setting(bool, AlwaysShieldBoost, SetShieldBoost)
	Setting(int, ActiveShieldBoost, SetActiveShieldBoost)
	Setting(int, ActiveShieldCap, SetActiveShieldCap)
	Setting(bool, AlwaysArmorRepair, SetArmorRepair)
	Setting(int, ActiveArmorRepair, SetActiveArmorRepair)
	Setting(int, ActiveArmorCap, SetActiveArmorCap)
	Setting(bool, Cloak, SetCloak)
	Setting(bool, GangLink, SetGangLink)
	Setting(bool, SensorBoosters, SetSensorBoosters)
	Setting(bool, AutoTarget, SetAutoTarget)
	Setting(bool, TrackingComputers, SetTrackingComputers)
	Setting(bool, ECCM, SetECCM)
	Setting(bool, DroneControlUnit, SetDroneControlUnit)
	Setting(int, ShieldBoostOverloadThreshold, SetShieldBoostOverloadThreshold)
	Setting(int, ArmorRepairOverloadThreshold, SetArmorRepairOverloadThreshold)
}

objectdef obj_AutoModule inherits obj_StateQueue
{
	variable obj_Configuration_AutoModule Config
	variable bool SafetyOveride=FALSE
	variable bool DropCloak=FALSE


	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		This.PulseFrequency:Set[1500]
		DynamicAddMiniMode("AutoModule", "AutoModule")

		This.LogLevelBar:Set[${CommonConfig.LogLevelBar}]
	}

	method Start()
	{
		This:QueueState["AutoModule"]
	}

	method Stop()
	{
		This:Clear
	}

	variable int lastArmorRepActivate = 0
	member:bool AutoModule()
	{
		variable index:module modules
		variable iterator m

		if !${Client.InSpace} || ${SafetyOveride}
		{
			return FALSE
		}
		variable string cloak
		variable bool cloakon
		MyShip:GetModules[modules]
		modules:GetIterator[m]
		if ${m:First(exists)}
		{
			do
			{
				if ${m.Value.ToItem.Group.Equal[Cloaking Device]}
				{
					cloak:Set[${m.Value.Slot}]
					if ${m.Value.IsActive} && !${m.Value.IsDeactivating}
						cloakon:Set[TRUE]
				}
			}
			while ${m:Next(exists)}
		}

		if ${cloak.NotNULLOrEmpty} && ${Config.Cloak}
		{
			if ${This.DropCloak}
			{
				if ${cloakon}
					MyShip.Module[${cloak}]:Deactivate
			}
			elseif !${cloakon} && !${Entity[Distance < 2000 && !IsPC]} && !${Entity[IsTargetingMe]} && !${Me.ToEntity.IsCloaked}
			{
				MyShip.Module[${cloak}]:Activate
			}
			elseif ${Me.ToEntity.IsCloaked}
			{
				variable index:int DestinationList
				EVE:GetToDestinationPath[DestinationList]
				if ${Entity[Distance <= 2500 && Name = \"${Universe[${DestinationList[1]}].Name}\"]} && ${cloakon}
				{
					MyShip.Module[${cloak}]:Deactivate
				}
				if ${Entity[Distance <= 2500 && Name = \"${EVE.Station[${DestinationList[1]}].Name}\"]} && ${cloakon}
				{
					MyShip.Module[${cloak}]:Deactivate
				}
				return FALSE
			}
		}

		if ${Ship.ModuleList_Ancillary_Shield_Booster.InactiveCount} && \
			${Ship.RegisteredModule.Element[${Ship.ModuleList_Ancillary_Shield_Booster.ModuleID.Get[1]}].CurrentCharges(exists)} && \
			${Ship.RegisteredModule.Element[${Ship.ModuleList_Ancillary_Shield_Booster.ModuleID.Get[1]}].CurrentCharges} <= ${Ship.ModuleList_Ancillary_Shield_Booster.ReloadChargeThreshold} && \
			!${FightOrFlight.IsEngagingGankers}
		{
			; This:LogInfo["Reloading ${Ship.RegisteredModule.Element[${Ship.ModuleList_Ancillary_Shield_Booster.ModuleID.Get[1]}].Type} at charge ${Ship.RegisteredModule.Element[${Ship.ModuleList_Ancillary_Shield_Booster.ModuleID.Get[1]}].CurrentCharges}"]
			Ship.ModuleList_Ancillary_Shield_Booster:ReloadDefaultAmmo
		}

		; Only difference to the Regen_Shield group is start/stop condition when engaging gankers.
		if ${Ship.ModuleList_Ancillary_Shield_Booster.InactiveCount} && \
			((${MyShip.ShieldPct.Int} < ${Config.ActiveShieldBoost} && ${MyShip.CapacitorPct.Int} > ${Config.ActiveShieldCap}) || \
			(${MyShip.ShieldPct.Int} < 90 && ${MyShip.CapacitorPct.Int} > 25 && ${FightOrFlight.IsEngagingGankers}) || \
			${Config.AlwaysShieldBoost})
		{
			if ${MyShip.ShieldPct.Int} < ${Config.ShieldBoostOverloadThreshold}
			{
				; 50 is module hp percent not the shield percent.
				Ship.ModuleList_Ancillary_Shield_Booster:SetOverloadHPThreshold[50]
			}
			elseif !${FightOrFlight.IsEngagingGankers}
			{
				Ship.ModuleList_Ancillary_Shield_Booster:SetOverloadHPThreshold[100]
			}
			Ship.ModuleList_Ancillary_Shield_Booster:ActivateAll
		}
		if ${Ship.ModuleList_Ancillary_Shield_Booster.ActiveCount} && \
			!${Config.AlwaysShieldBoost} && \
			( \
				(!${FightOrFlight.IsEngagingGankers} && (${MyShip.ShieldPct.Int} > ${Config.ActiveShieldBoost} || ${MyShip.CapacitorPct.Int} < ${Config.ActiveShieldCap})) || \
				(${FightOrFlight.IsEngagingGankers} && \
					( \
						((${MyShip.ShieldPct.Int} >= 90) && ${Ship.RegisteredModule.Element[${Ship.ModuleList_Ancillary_Shield_Booster.ModuleID.Get[1]}].CurrentCharges(exists)}) || \
						(!${Ship.RegisteredModule.Element[${Ship.ModuleList_Ancillary_Shield_Booster.ModuleID.Get[1]}].CurrentCharges(exists)} && (${MyShip.CapacitorPct.Int} <= 25)) \
					) \
				) \
			)
		{
			Ship.ModuleList_Ancillary_Shield_Booster:SetOverloadHPThreshold[100]
			Ship.ModuleList_Ancillary_Shield_Booster:DeactivateAll
		}

		if ${Ship.ModuleList_Regen_Shield.InactiveCount} && \
			((${MyShip.ShieldPct.Int} < ${Config.ActiveShieldBoost} && ${MyShip.CapacitorPct.Int} > ${Config.ActiveShieldCap}) || \
			(${MyShip.ShieldPct.Int} < 90 && ${MyShip.CapacitorPct.Int} > 15 && ${FightOrFlight.IsEngagingGankers}) || \
			${Config.AlwaysShieldBoost})
		{
			if ${MyShip.ShieldPct.Int} < ${Config.ShieldBoostOverloadThreshold}
			{
				; 50 is module hp percent not the shield percent.
				Ship.ModuleList_Regen_Shield:SetOverloadHPThreshold[50]
			}
			elseif !${FightOrFlight.IsEngagingGankers}
			{
				Ship.ModuleList_Regen_Shield:SetOverloadHPThreshold[100]
			}
			Ship.ModuleList_Regen_Shield:ActivateAll
		}
		if ${Ship.ModuleList_Regen_Shield.ActiveCount} && \
			!${Config.AlwaysShieldBoost} && \
			(((${MyShip.ShieldPct.Int} > ${Config.ActiveShieldBoost} || ${MyShip.CapacitorPct.Int} < ${Config.ActiveShieldCap}) && !${FightOrFlight.IsEngagingGankers}) || \
			((${MyShip.ShieldPct.Int} >= 90 || ${MyShip.CapacitorPct.Int} <= 15) && ${FightOrFlight.IsEngagingGankers}))
		{
			Ship.ModuleList_Regen_Shield:SetOverloadHPThreshold[100]
			Ship.ModuleList_Regen_Shield:DeactivateAll
		}

		if ${Ship.ModuleList_Repair_Armor.InactiveCount} && \
			((${MyShip.ArmorPct.Int} < ${Config.ActiveArmorRepair} && ${MyShip.CapacitorPct.Int} > ${Config.ActiveArmorCap}) || \
			(${MyShip.ArmorPct.Int} < 85 && ${MyShip.CapacitorPct.Int} > 15 && ${FightOrFlight.IsEngagingGankers}) || \
			${Config.AlwaysArmorRepair})
		{
			if ${MyShip.ArmorPct.Int} < ${Config.ArmorRepairOverloadThreshold}
			{
				; 50 is module hp percent not the armor percent.
				Ship.ModuleList_Repair_Armor:SetOverloadHPThreshold[50]
			}
			elseif !${FightOrFlight.IsEngagingGankers}
			{
				Ship.ModuleList_Repair_Armor:SetOverloadHPThreshold[100]
			}

			Ship.ModuleList_Repair_Armor:ActivateAll
			; lastArmorRepActivate:Set[${Math.Calc[${LavishScript.RunningTime} + 3000]}]
		}

		if ${Ship.ModuleList_Repair_Armor.ActiveCount} && \
			!${Config.AlwaysArmorRepair} && \
			(((${MyShip.ArmorPct.Int} > ${Config.ActiveArmorRepair} || ${MyShip.CapacitorPct.Int} < ${Config.ActiveArmorCap}) && !${FightOrFlight.IsEngagingGankers}) || \
			((${MyShip.ArmorPct.Int} >= 85 || ${MyShip.CapacitorPct.Int} <= 15) && ${FightOrFlight.IsEngagingGankers}))
		{
			Ship.ModuleList_Repair_Armor:SetOverloadHPThreshold[100]
			Ship.ModuleList_Repair_Armor:DeactivateAll
		}

		if ${Ship.ModuleList_ActiveResists.Count} && ${Config.ActiveHardeners} && !${Me.ToEntity.IsCloaked}
		{
			Ship.ModuleList_ActiveResists:ActivateAll
		}

		if ${Ship.ModuleList_GangLinks.ActiveCount} < ${Ship.ModuleList_GangLinks.Count} && ${Me.ToEntity.Mode} != MOVE_WARPING && ${Config.GangLink}
		{
			Ship.ModuleList_GangLinks:ActivateAll
		}

		if ${Ship.ModuleList_SensorBoost.ActiveCount} < ${Ship.ModuleList_SensorBoost.Count} && ${Config.SensorBoosters} && !${Me.ToEntity.IsCloaked}
		{
			Ship.ModuleList_SensorBoost:ActivateAll
		}

		if ${Ship.ModuleList_AutoTarget.ActiveCount} < ${Ship.ModuleList_AutoTarget.Count} && ${Config.AutoTarget} && !${Me.ToEntity.IsCloaked}
		{
			Ship.ModuleList_AutoTarget:ActivateAll
		}

		if ${Ship.ModuleList_TrackingComputer.ActiveCount} < ${Ship.ModuleList_TrackingComputer.Count} && ${Config.TrackingComputers} && !${Me.ToEntity.IsCloaked}
		{
			Ship.ModuleList_TrackingComputer:ActivateFor[TARGET_ANY]
		}

		if ${Ship.ModuleList_ECCM.ActiveCount} < ${Ship.ModuleList_ECCM.Count} && ${Config.ECCM} && !${Me.ToEntity.IsCloaked}
		{
			Ship.ModuleList_ECCM:ActivateAll
		}

		if ${Ship.ModuleList_DroneControlUnit.ActiveCount} < ${Ship.ModuleList_DroneControlUnit.Count} && ${Config.DroneControlUnit}
		{
			This:LogInfo["Activating DroneControlUnit"]
			Ship.ModuleList_DroneControlUnit:ActivateAll
		}
		if ${Ship.ModuleList_Repair_Armor.Count} > 1 && ${Ship.ModuleList_AssaultDamageControl.Count} > 1
		{
			if ${MyShip.ArmorPct.Int} < 30 && ${MyShip.ArmorPct.Int} >= 0
			{
				This:LogInfo["Activating Assault DC"]
				Ship.ModuleList_AssaultDamageControl:ActivateAll
			}
		}
		if ${Ship.ModuleList_Repair_Armor.Count} < 1 && ${Ship.ModuleList_AssaultDamageControl.Count} > 1
		{
			if ${MyShip.ShieldPct.Int} < 30
			{
				This:LogInfo["Activating Assault DC"]
				Ship.ModuleList_AssaultDamageControl:ActivateAll
			}
		}
		return FALSE
	}

}