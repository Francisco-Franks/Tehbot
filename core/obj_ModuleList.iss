objectdef obj_ModuleList inherits obj_Logger
{
	variable index:int64 ModuleID
	variable bool Allowed = TRUE

	method Initialize(string Details)
	{
		This.LogLevelBar:Set[${CommonConfig.LogLevelBar}]
	}

	method Insert(int64 ID)
	{
		ModuleID:Insert[${ID}]
	}

	method ActivateOne(int64 targetID = TARGET_NA)
	{
		if !${Allowed}
		{
			This:LogInfo["Not allowed to activate."]
			return
		}

		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsInstructionMatch[INSTRUCTION_NONE]}
				{
					Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:GiveInstruction[INSTRUCTION_ACTIVATE_ON, ${targetID}]
					return
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	; When all tractor beams are already assigned, force re-assign one tractor beam to the prioritized target.
	method ForceActivateOne(int64 targetID = TARGET_NA)
	{
		if !${Allowed}
		{
			This:LogInfo["Not allowed to activate."]
			return
		}

		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:GiveInstruction[INSTRUCTION_ACTIVATE_ON, ${targetID}]
		}
	}

	method ActivateAll(int64 targetID = TARGET_NA)
	{
		if !${Allowed}
		{
			This:LogInfo["Not allowed to activate."]
			return
		}

		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:GiveInstruction[INSTRUCTION_ACTIVATE_ON, ${targetID}]
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	method ConfigureAmmo(string shortRangeAmmo, string longRangeAmmo)
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:ConfigureAmmo[${shortRangeAmmo}, ${longRangeAmmo}]
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	method ActivateFor(int64 targetID = TARGET_NA)
	{
		if !${Allowed}
		{
			This:LogInfo["Not allowed to activate."]
			return
		}

		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:GiveInstruction[INSTRUCTION_ACTIVATE_FOR, ${targetID}]
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	method ReloadDefaultAmmo()
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:GiveInstruction[INSTRUCTION_RELOAD_AMMO, TARGET_NA]
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	method DeactivateAll()
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsActive}
				{
					Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:GiveInstruction[INSTRUCTION_DEACTIVATE]
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	method DeactivateOneNotOn(int64 targetID)
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]

		; Already deactivating one?
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsInstructionMatch[INSTRUCTION_DEACTIVATE]}
				{
					return
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}

		; Deactivate if not.
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if !${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsModuleActiveOn[${targetID}]} && ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsActive}
				{
					Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:GiveInstruction[INSTRUCTION_DEACTIVATE]
					return
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	method DeactivateOn(int64 targetID)
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsModuleActiveOn[${targetID}]}
				{
					Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:GiveInstruction[INSTRUCTION_DEACTIVATE]
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	method SetOverloadHPThreshold(int threshold)
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				Ship.RegisteredModule.Element[${moduleIDIterator.Value}].OverloadIfHPAbovePercent:Set[${threshold}]
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	member:bool IsActiveOn(int64 targetID)
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsInstructionMatch[INSTRUCTION_ACTIVATE_ON, ${targetID}]}
				{
					return TRUE
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
		return FALSE
	}

	member:int Count()
	{
		return ${ModuleID.Used}
	}

	member:int ActiveCount()
	{
		variable int countActive=0
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsActive}
				{
					countActive:Inc
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
		return ${countActive}
	}

	member:int ActiveCountOn(int64 targetID)
	{
		variable int countActive=0
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsModuleActiveOn[${targetID}]}
				{
					countActive:Inc
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
		return ${countActive}
	}

	member:int InactiveCount()
	{
		variable iterator moduleIDIterator
		variable int countInactive = 0
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsInstructionMatch[INSTRUCTION_NONE]}
				{
					countInactive:Inc
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
		return ${countInactive}
	}
	member:int64 ID()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].ID}
	}
	member:string Type()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].Type}
	}
	member:int64 TypeID()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].TypeID}
	}
	member:float Range()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].Range}
	}
	member:float GroupID()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].GroupID}
	}

	member:float OptimalRange()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].OptimalRange}
	}

	member:float TrackingSpeed()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].TrackingSpeed}
	}

	member:float AccuracyFalloff()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].AccuracyFalloff}
	}

	member:float DamageModifier()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].DamageModifier}
	}

	member:float RateOfFire()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].RateOfFire}
	}
	
	member:float DamageEfficiency(int64 targetID)
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].DamageEfficiency[${targetID}]}
	}

	member:float TurretTrackingDecayFactor(int64 targetID)
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}]._turretTrackingDecayFactor[${targetID}]}
	}

	member:string FallbackAmmo()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].FallbackAmmo}
	}

	member:string FallbackLongRangeAmmo()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].FallbackLongRangeAmmo}
	}

	member:int ReloadChargeThreshold()
	{
		if ${ModuleID.Used}
		{
			return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].ReloadChargeThreshold}
		}

		return 0
	}

	member:bool IsUsingLongRangeAmmo()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].IsUsingLongRangeAmmo}
	}

	member:string GetFallthroughObject()
	{
		return "Ship.${This.ObjectName}.ModuleID"
	}
}