objectdef obj_Module inherits obj_StateQueue
{
	variable int Instruction = INSTRUCTION_NONE
	variable int64 InstructionTargetID = TARGET_NA
	variable int64 ModuleID

	variable string Ammo
	variable string LongRangeAmmo
	variable string XtraLongRangeAmmo

	variable int64 LastAmmoChange

	variable int _lastDeactivationTimestamp
	variable int _deactivationRetryInterval = 2000
	variable int _lastChangeAmmoTimestamp
	variable int _changeAmmoRetryInterval = 2000
	; TODO: Switch ammo when grouped laser weapon is taking too long to activate, may be caused by crystal burnt out.
	variable int _lastActivationTimestamp
	variable int _activationRetryInterval = 2000

	; TODO actually the intervals above are not needed anymore after _tooSoon() is introduced.
	variable int _intervalBetweenOperations = 1000

	; This flag can be replaced by a member:bool which detects whether module attributes
	; has changed from base value. So we don't need to manage the value manually.
	;
	; But only if the following experiment succeed:
	;		Manually turn overload on while module is already on, see whether the
	;		attributes change BEFORE the next module cycle.
	;
	; But even if the experiment above shows desired result, the automatic flag is useless to
	; us until ToggleOn() and ToggleOff() methods are seperated, then it's possible to retry if
	; current toggling is taking too long -- Even in that case, we will need another variable as timer.
	;
	; So this bool flag is already the best option.
	variable bool _overloadToggledOn = FALSE
	variable int OverloadIfHPAbovePercent = 100

	variable float64 _shortRangeAmmoRange = 0

	method Initialize(int64 ID)
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		ModuleID:Set[${ID}]
		PulseFrequency:Set[1000]
	 	RandomDelta:Set[100]
		LogModuleName:Set["${This.Name}"]

		This.LogLevelBar:Set[${CommonConfig.LogLevelBar}]

		This:LogInfo["Initialize module ${ModuleID} ${This.Name}"]
		This:LogDebug["Test GetFallthroughObject pass: ${This._testGetFallthroughObject}"]
		This:Clear
		This:QueueState["Operate"]
	}

	member:string GetFallthroughObject()
	{
		return "MyShip.Module[${ModuleID}]"
	}

;;;;;;;;;;single state
	member:bool Operate()
	{
		if !${Me.InSpace}
		{
			This:_resetState
			return FALSE
		}

		if !${This.IsActivatable} || \
			!${This.IsOnline} || \
			${This.IsBeingRepaired} || \
			${This.IsReloading} || \
			${This.IsDeactivating} || \
			; ${Instruction.Equal[INSTRUCTION_NONE]} || \
			${This._tooSoon}
		{
			return FALSE
		}

		; Overload will be turned off automatically when module is deactivated, flag should follow.
		; Actually allow toggling at INSTRUCTION_NONE state as long as the flag reset
		; is ensured when erasing other instructions.
		if !${This.IsActive} && \
			!${This.IsInstructionMatch[INSTRUCTION_ACTIVATE_ON, TARGET_ANY]} && \
			!${This.IsInstructionMatch[INSTRUCTION_ACTIVATE_FOR, TARGET_ANY]}&& \
			!${This.IsInstructionMatch[INSTRUCTION_NONE, TARGET_ANY]}
		{
			_overloadToggledOn:Set[FALSE]
		}

		switch ${Instruction}
		{
			case INSTRUCTION_ACTIVATE_ON
				This:OperateActivateOn[${InstructionTargetID}]
				break
			case INSTRUCTION_ACTIVATE_FOR
				This:OperateActivateFor[${InstructionTargetID}]
				break
			case INSTRUCTION_DEACTIVATE
				This:OperateDeactivate
				break
			case INSTRUCTION_RELOAD_AMMO
				This:OperateReloadAmmo
				break
			case INSTRUCTION_NONE
				if ${This._toggleOverload}
				{
					return FALSE
				}
				break
		}

		return FALSE
	}

;;;;;;;;;;public interface
	member:bool IsModuleActiveOn(int64 targetID)
	{
		if ${This.IsActive} && ${This._targetMatch[${This.TargetID}, ${targetID}]}
		{
			return TRUE
		}

		return FALSE
	}

	; "Soon gonna do" status
	member:bool IsInstructionMatch(int newInstruction, int64 targetID = TARGET_NA)
	{
		if ${newInstruction} != ${Instruction}
		{
			return FALSE
		}

		return ${This._targetMatch[${InstructionTargetID}, ${targetID}]}
	}

	method GiveInstruction(int instruction, int64 targetID = TARGET_NA)
	{
		if !${This.IsActivatable} || \
			!${This.IsOnline} || \
			${This.IsBeingRepaired}
		{
			return
		}

		if ${This.IsInstructionMatch[${instruction}, ${targetID}]}
		{
			return
		}

		; Update instruction
		Instruction:Set[${instruction}]
		InstructionTargetID:Set[${targetID}]

		if ${This._tooSoon}
		{
			This:Clear
			This:QueueState["Operate", ${_intervalBetweenOperations}]
		}

		This:_resetTimers
	}

	method ConfigureAmmo(string shortRangeAmmo, string longRangeAmmo, string xtraLongRangeAmmo)
	{
		if (${shortRangeAmmo.NotNULLOrEmpty} && !${shortRangeAmmo.Equal[${Ammo}]}) || (${longRangeAmmo.NotNULLOrEmpty} && !${longRangeAmmo.Equal[${LongRangeAmmo}]}) || (${xtraLongRangeAmmo.NotNULLOrEmpty} && !${xtraLongRangeAmmo.Equal[${XtraLongRangeAmmo}]})
		{
			This:LogDebug["${This.Name} configured ammo as ${shortRangeAmmo} + ${longRangeAmmo} + ${xtraLongRangeAmmo}"]
			Ammo:Set[${shortRangeAmmo}]
			LongRangeAmmo:Set[${longRangeAmmo}]
			XtraLongRangeAmmo:Set[${xtraLongRangeAmmo}]
		}
	}

	; Deactivate module when target doesn't match or need to change ammo, then activate it on specified target.
	; Instruction is erased when the target is destroyed.
	method OperateActivateOn(int64 targetID)
	{
		if !${This._isTargetValid[${targetID}]}
		{
			This:_resetState
			return
		}

		variable string optimalAmmo
		if ${This.IsActive}
		{
			if !${This._targetMatch[${This.TargetID}, ${targetID}]}
			{
				This:LogDebug["Deactivating ${This.Name} to switch target, current Target ${This.TargetID} ${Entity[${This.TargetID}].Name} new target ${targetID} ${Entity[${targetID}].Name}."]
				This:_deactivate
				return
			}
			; target already match

			if ${targetID} != TARGET_NA
			{
				optimalAmmo:Set[${This._pickOptimalAmmo[${targetID}]}]
				if ${optimalAmmo.NotNULLOrEmpty} && !${This.Charge.Type.Equal[${optimalAmmo}]} && ((${LavishScript.RunningTime} > ${LastAmmoChange}) || (${Ship.ModuleList_Lasers.Count} > 0))
				{
					This:LogDebug["${This.Name} optimalAmmo is ${optimalAmmo} for ${Entity[${targetID}].Name} distance ${Entity[${targetID}].Distance}"]
					This:LogDebug["Deactivating ${This.Name} to change ammo to ${optimalAmmo}."]
					LastAmmoChange:Set[${Math.Calc[${LavishScript.RunningTime} + 30000]}]
					This:_deactivate	
					return
				}
			}
			; ammo already match

			if ${This._toggleOverload}
			{
				; Add bit delay.
				return
			}

			; Finished
			This:_resetTimers
			return
		}
		else
		{
			_lastDeactivationTimestamp:Set[0]

			optimalAmmo:Set[${This._pickOptimalAmmo[${targetID}]}]
			if ${optimalAmmo.NotNULLOrEmpty} && !${optimalAmmo.Equal[${This.Charge.Type}]} && ((${LavishScript.RunningTime} > ${LastAmmoChange}) || (${Ship.ModuleList_Lasers.Count} > 0))
			{
				This:_findAndChangeAmmo[${optimalAmmo}]
				LastAmmoChange:Set[${Math.Calc[${LavishScript.RunningTime} + 30000]}]
				return
			}
			else
			{
				_lastChangeAmmoTimestamp:Set[0]

				if ${This._isTargetValid[${targetID}]}
				{
					if ${This._toggleOverload}
					{
						; Add bit delay.
						return
					}

					This:_activate[${targetID}]
				}
				else
				{
					This:LogDebug["${This.Name} reset state for target is gone"]
					This:_resetState
				}
				return
			}
		}
	}

	; Load the optimal ammo and activate module,
	; Instruction is kept forever.
	; Used with tracking computers, guidance computers, etc.
	; The difference from OperateActivateOn is that it won't deactivate the module just because target changed.
	; TODO: Add unload script path when the ISXEVE api is fixed.
	method OperateActivateFor(int64 targetID)
	{
		variable string optimalAmmo
		if ${This.IsActive}
		{
			optimalAmmo:Set[${This._pickOptimalAmmo[${targetID}]}]
			if ${optimalAmmo.NotNULLOrEmpty} && !${optimalAmmo.Equal[${This.Charge.Type}]}
			{
				This:LogDebug["${This.Name} optimalAmmo is ${optimalAmmo} for ${Entity[${targetID}].Name} distance ${Entity[${targetID}].Distance}"]
				This:LogDebug["Deactivating ${This.Name} to change ammo to ${optimalAmmo}."]
				This:_deactivate
				return
			}
			; ammo already match

			if ${This._toggleOverload}
			{
				; Add bit delay.
				return
			}

			; Finished
			This:_resetTimers
			return
		}
		else
		{
			_lastDeactivationTimestamp:Set[0]

			optimalAmmo:Set[${This._pickOptimalAmmo[${targetID}]}]
			if ${optimalAmmo.NotNULLOrEmpty} && !${optimalAmmo.Equal[${This.Charge.Type}]}
			{
				This:_findAndChangeAmmo[${optimalAmmo}]
				return
			}
			else
			{
				; ammo already match
				_lastChangeAmmoTimestamp:Set[0]

				if ${This._toggleOverload}
				{
					; Add bit delay.
					return
				}

				This:_activate[TARGET_NA]
				return
			}
		}
	}

	; Deactivate module.
	; Instruction is erased after module is turned off.
	method OperateDeactivate()
	{
		variable string optimalAmmo
		if ${This.IsActive}
		{
			This:_deactivate
			return
		}
		else
		{
			; Finished
			This:_resetState
			return
		}
	}

	; Load the default ammo,
	; Instruction is erased when ammo type and amount matches.
	; Used while warping.
	method OperateReloadAmmo()
	{
		variable string defaultAmmo
		if ${This.IsActive}
		{
			This:_deactivate
			return
		}
		else
		{
			_lastDeactivationTimestamp:Set[0]

			defaultAmmo:Set[${This._getDefaultAmmo}]

			; ${MyShip.Cargo[${defaultAmmo}]} will return the first unstacked item instance of item, for crystals, the quantity is likely to be 1.
			; so we set the Quantity threshold to 0 instead of ${WeaponSwitch}.Count until a (TODO) improved quantity method is implemented.
			if (!${defaultAmmo.NotNULLOrEmpty} || !${defaultAmmo.Equal[${This.Charge.Type}]}) && (${MyShip.Cargo[${defaultAmmo}].Quantity} > 0)
			{
				This:_findAndChangeAmmo[${defaultAmmo}]
				return
			}
			elseif !${This.ToItem.GroupID.Equal[GROUP_ENERGYWEAPON]} && \
				${defaultAmmo.Equal[${This.Charge.Type}]} && \
				(${This.CurrentCharges} < ${This.MaxCharges}) && \    /*${This.CurrentCharges} is 0 for energy weapons it seems*/
				(${MyShip.Cargo[${defaultAmmo}].Quantity} > ${Ship.${WeaponSwitch}.Count})
			{
				; This:_findAndChangeAmmo[${defaultAmmo}]
				This:_reloadAmmo
				return
			}
			else
			{
				; Finished
				This:_resetState
				return
			}
		}
	}

;;;;;;;;;;private

	member:bool _testGetFallthroughObject()
	{
		; ${This.Duration} is NULL for weapons.
		; ${This.LastTarget} ${This.TargetID} are NULL until target exists.
		if ${This.Name.NotNULLOrEmpty} && \
			${This.IsReloading(type).Name.Equal[bool]} && \
			${This.IsOnline(type).Name.Equal[bool]} && \
			${This.IsGoingOnline(type).Name.Equal[bool]} && \
			${This.IsDeactivating(type).Name.Equal[bool]} && \
			${This.IsActivatable(type).Name.Equal[bool]} && \
			${This.IsAutoReloadOn(type).Name.Equal[bool]} && \
			${This.AutoRepeat(type).Name.Equal[bool]} && \
			${This.IsActive(type).Name.Equal[bool]} && \
			${This.HP(type).Name.Equal[float64]} && \
			${This.Damage(type).Name.Equal[float64]}
		{
			return TRUE
		}
		return FALSE
	}

	member:bool _isTargetValid(int64 targetID)
	{
		if (${targetID} != TARGET_NA) && \
			!(${Entity[${targetID}](exists)} && !${Entity[${targetID}].IsMoribund} && ${Entity[${targetID}].IsLockedTarget})
		{
			This:LogDebug["${This.Name} reset state for target is invalid."]
			This:_resetState
			return FALSE
		}
		elseif ((${This.ToItem.GroupID} == GROUP_SALVAGER) || (${This.ToItem.GroupID} == GROUP_TRACTOR_BEAM)) && \
			(${Entity[${targetID}].Distance} > ${This.Range})
		{
			; It's possible that ship moves away from wreck while salvaging.
			This:LogDebug["${This.Name} reset state for target is out of range."]
			This:_resetState
			return FALSE
		}

		return TRUE
	}

	method _resetState()
	{
		Instruction:Set[INSTRUCTION_NONE]
		InstructionTargetID:Set[TARGET_NA]
		_overloadToggledOn:Set[FALSE]
		This:_resetTimers
	}

	method _resetTimers()
	{
		_lastDeactivationTimestamp:Set[0]
		_lastChangeAmmoTimestamp:Set[0]
		_lastActivationTimestamp:Set[0]
	}

	; A bug will cause the module get stuck if interval between commands is too small.
	member:bool _tooSoon()
	{
		if (${Math.Calc[${LavishScript.RunningTime} - ${_lastActivationTimestamp}]} <= ${_intervalBetweenOperations}) || \
			(${Math.Calc[${LavishScript.RunningTime} - ${_lastChangeAmmoTimestamp}]} <= ${_intervalBetweenOperations}) || \
			(${Math.Calc[${LavishScript.RunningTime} - ${_lastDeactivationTimestamp}]} <= ${_intervalBetweenOperations})
		{
			return TRUE
		}

		return FALSE
	}

	member:bool _targetMatch(int64 currentTargetID, int64 newTargetID)
	{
		; NULL are treated as 0.

		; variable bool nullIsFALSE
		; nullIsFALSE:Set[!${This.TargetID}]

		; variable bool nullEqualsZero = FALSE
		; if ${This.TargetID} == 0
		; nullEqualsZero:Set[TRUE]

		; Validated both true

		; This:LogInfo[current target id ${currentTargetID} new target id ${newTargetID} equal NA ${newTargetID.Equal[TARGET_NA]}]
		if ${newTargetID.Equal[TARGET_ANY]}
		{
			return TRUE
		}

		if ${newTargetID.Equal[${currentTargetID}]}
		{
			return TRUE
		}

		return FALSE
	}

	method _activate(int64 targetID)
	{
		if !${This._isTargetValid[${targetID}]}
		{
			This:_resetState
			return
		}

		if ${_lastActivationTimestamp} == 0
		{
			This:LogDebug["Activating ${This.Name} on ${targetID} ${Entity[${targetID}].Name}"]
			_lastActivationTimestamp:Set[${LavishScript.RunningTime}]
			if ${targetID} == TARGET_NA
			{
				This:Activate
			}
			else
			{
				This:Activate[${targetID}]
			}
		}
		elseif ${LavishScript.RunningTime} > ${Math.Calc[${_lastActivationTimestamp} + ${_activationRetryInterval}]}
		{
			This:LogDebug["Retrying activate ${This.Name} on ${targetID} ${Entity[${targetID}].Name}"]
			_lastActivationTimestamp:Set[${LavishScript.RunningTime}]
			if ${targetID} == TARGET_NA
			{
				This:Activate
			}
			else
			{
				This:Activate[${targetID}]
			}
		}
	}

	method _deactivate()
	{
		_overloadToggledOn:Set[FALSE]
		if ${_lastDeactivationTimestamp} == 0
		{
			This:LogDebug["Deactivating ${This.Name}"]
			_lastDeactivationTimestamp:Set[${LavishScript.RunningTime}]
			This:Deactivate
		}
		elseif ${LavishScript.RunningTime} > ${Math.Calc[${_lastDeactivationTimestamp} + ${_deactivationRetryInterval}]}
		{
			This:LogDebug["Retrying deactivate ${This.Name}"]
			_lastDeactivationTimestamp:Set[${LavishScript.RunningTime}]
			This:Deactivate
		}
	}

	method _changeAmmo(int64 ammoID, int ammoAmount, string ammoName)
	{
		if ${_lastChangeAmmoTimestamp} == 0
		{
			This:LogInfo["Switching ${This.Name} charge to \ay${ammoName}"]
			_lastChangeAmmoTimestamp:Set[${LavishScript.RunningTime}]
			This:ChangeAmmo[${ammoID}, ${ammoAmount}]
		}
		elseif ${LavishScript.RunningTime} > ${Math.Calc[${_lastChangeAmmoTimestamp} + ${_changeAmmoRetryInterval}]}
		{
			This:LogInfo["Retrying ${This.Name} switching charge to \ay${ammoName}"]
			_lastChangeAmmoTimestamp:Set[${LavishScript.RunningTime}]
			This:ChangeAmmo[${ammoID}, ${ammoAmount}]
		}
	}

	method _reloadAll()
	{
		if ${_lastChangeAmmoTimestamp} == 0
		{
			This:LogInfo["Reloading charge."]
			_lastChangeAmmoTimestamp:Set[${LavishScript.RunningTime}]
			EVE:Execute[CmdReloadAmmo]
		}
		elseif ${LavishScript.RunningTime} > ${Math.Calc[${_lastChangeAmmoTimestamp} + ${_changeAmmoRetryInterval}]}
		{
			This:LogInfo["Retrying reload charge."]
			_lastChangeAmmoTimestamp:Set[${LavishScript.RunningTime}]
			EVE:Execute[CmdReloadAmmo]
		}
	}

	member:string _pickOptimalAmmo(int64 targetID)
	{
		switch ${This.ToItem.GroupID}
		{
			case GROUP_PROJECTILEWEAPON
			case GROUP_ENERGYWEAPON
			case GROUP_HYBRIDWEAPON
			case GROUP_PRECURSORWEAPON
			case GROUP_VORTONWEAPON
				return ${This._pickOptimalAmmoForTurret[${InstructionTargetID}]}
			case GROUP_TRACKINGCOMPUTER
				return ${This._pickOptimalScriptTrackingComputerScript[${InstructionTargetID}]}
			case GROUP_MISSILEGUIDANCECOMPUTER
				return ${This._pickOptimalScriptMissileGuidanceComputerScript[${InstructionTargetID}]}
			case GROUP_MISSILELAUNCHERRAPIDHEAVY
			case GROUP_MISSILELAUNCHER
			case GROUP_MISSILELAUNCHERASSAULT
			case GROUP_MISSILELAUNCHERBOMB
			case GROUP_MISSILELAUNCHERCITADEL
			case GROUP_MISSILELAUNCHERCRUISE
			case GROUP_MISSILELAUNCHERDEFENDER
			case GROUP_MISSILELAUNCHERHEAVY
			case GROUP_MISSILELAUNCHERHEAVYASSAULT
			case GROUP_MISSILELAUNCHERROCKET
			case GROUP_MISSILELAUNCHERTORPEDO
			case GROUP_MISSILELAUNCHERSTANDARD
				return ${This._pickOptimalAmmoForMissileLauncher[${InstructionTargetID}]}
		}

		return ""
	}

	member:string _pickOptimalAmmoForTurret(int64 targetID)
	{
		if ${targetID.Equal[TARGET_NA]} || !${This._isTargetValid[${targetID}]}
		{
			This:LogCritical["Picking turret ammo for invalid target."]
			return ""
		}

		if ${AmmoOverride.NotNULLOrEmpty}
		{
			if ${MyShip.Cargo[${AmmoOverride}].Quantity} > 0 || (${This.Charge.Type.Equal[${AmmoOverride}]} && ${This.Charge.Quantity} > 0)
			{
				;This:LogInfo["Selection ${AmmoOverride} as our Ammo Override"]
				return ${AmmoOverride}
			}
		}

        ; No time to switch ammo when PVP.
	    ; But energy weapons can switch ammo immediately so it should always simply pick the optimal ammo for the current target.
		if ${This.ToItem.GroupID.Equal[GROUP_PROJECTILEWEAPON]} && \
		    ${This.Charge(exists)} && ${Entity[${targetID}].IsPC}
		{
			return ""
		}
		if ${This.ToItem.TypeID.Equal[TYPE_VORTON_WEAPON]} && \
		    ${Entity[${targetID}].Distance} < 40000
		{
			return "ElectroPunch Ultra L"
		}
		if ${This.ToItem.TypeID.Equal[TYPE_VORTON_WEAPON]} && \
		    ${Entity[${targetID}].Distance} > 40000
		{
			return "StrikeSnipe Ultra L"
		}
		
		if ${This.ToItem.TypeID.Equal[TYPE_VORTON_WEAPON_MED]} && \
		    ${Entity[${targetID}].Distance} < 32000
		{
			return "ElectroPunch Ultra M"
		}
		if ${This.ToItem.TypeID.Equal[TYPE_VORTON_WEAPON_MED]} && \
		    ${Entity[${targetID}].Distance} > 32000 && ${Entity[${targetID}].Distance} < 49000
		{
			return "GalvaSurge Condenser Pack M"
		}
		if ${This.ToItem.TypeID.Equal[TYPE_VORTON_WEAPON_MED]} && \
		    ${Entity[${targetID}].Distance} > 49000
		{
			return "StrikeSnipe Ultra M"
		}


		variable string shortRangeAmmo
		shortRangeAmmo:Set[${This._getDefaultAmmo}]

		variable string longRangeAmmo
		longRangeAmmo:Set[${This._getDefaultLongRangeAmmo}]
		
		variable string xtraLongRangeAmmo
		xtraLongRangeAmmo:Set[${This._getDefaultXtraLongRangeAmmo}]

		if ${This.Charge(exists)} && ${This.Charge.Type.Equal[${shortRangeAmmo}]}
		{
			; Giveup memorizing short range ammo for it won't work correctly when tracking disrupted.
			; Memorize the short range ammo range.
			; Band-aid of a bug that range update is dealyed after swiching.
			; if ${This.Range} < 70
			; {
			; 	_shortRangeAmmoRange:Set[${Utility.Max[${_shortRangeAmmoRange}, ${This.Range}]}]
			; }
			; This:LogInfo["Ammo match: ${This.Charge.Type} = ${shortRangeAmmo} ? ${This.Charge.Type.Equal[${shortRangeAmmo}]}"]
			; This:LogInfo["Cached range: ${_shortRangeAmmoRange}, ${This.Range} -> ${_shortRangeAmmoRange}"]

			if ${Entity[${targetID}].Distance} <= ${This.Range}
			{
				return ${shortRangeAmmo}
			}
			elseif ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
			{
				return ${longRangeAmmo}
			}
			else
			{
				return ${shortRangeAmmo}
			}
		}
		elseif ${This.Charge(exists)} && ${This.Charge.Type.Equal[${longRangeAmmo}]}
		{
			if ${Entity[${targetID}].Distance} <= ${Math.Calc[${This.Range} * 0.4]}
			{
				if  ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
					return ${shortRangeAmmo}
				}
				else
				{
					return ${longRangeAmmo}
				}
			}
			else
			{
				return ${longRangeAmmo}
			}
		}
		else /*no ammo exist or unknown ammo loaded*/
		{
			if ${Entity[${targetID}].Distance} <= ${This.Range}
			{
				if ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
					return ${shortRangeAmmo}
				}
				elseif ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
				{
					return ${longRangeAmmo}
				}
			}
			else
			{
				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
				{
					return ${longRangeAmmo}
				}
				elseif  ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
					return ${shortRangeAmmo}
				}
			}
		}

		This:LogCritical["No configured ammo in cargo!"]
		return ""
	}

	member:string _pickOptimalAmmoForMissileLauncher(int64 targetID)
	{
		if ${targetID.Equal[TARGET_NA]} || !${This._isTargetValid[${targetID}]}
		{
			This:LogCritical["Picking turret ammo for invalid target."]
			return ""
		}
		
		if ${AmmoOverride.NotNULLOrEmpty}
		{
			if ${MyShip.Cargo[${AmmoOverride}].Quantity} > 0 || (${This.Charge.Type.Equal[${AmmoOverride}]} && ${This.Charge.Quantity} > 0)
			{
				;This:LogInfo["Selecting ${AmmoOverride} as our Ammo Override"]
				return ${AmmoOverride}
			}
		}
		
		; No time to switch ammo when PVP.
		if ${This.Charge(exists)} && ${Entity[${targetID}].IsPC}
		{
			return ""
		}

		variable string shortRangeAmmo
		shortRangeAmmo:Set[${This._getDefaultAmmo}]

		variable string longRangeAmmo
		longRangeAmmo:Set[${This._getDefaultLongRangeAmmo}]

		; Giveup timing ammo change according to remaining ammo quantity.
		; Because it won't work correctly unless enemy HP is taken into account, which is too much work.
		; Example:
		;     Only switch ammo when remaining ammo is less than 15, so it will keep the current charge when
		;     quantity is 16, but as soon as it drops below 15, ammo switch will occur so we failed to any save time.
		; Just switch ammo when you want to.
		if ${This.Charge(exists)} && ${This.Charge.Type.Equal[${shortRangeAmmo}]}
		{
			; Memorize the short range ammo range.
			_shortRangeAmmoRange:Set[${Utility.Max[${_shortRangeAmmoRange}, ${This.Range}]}]

            ; Use cached threshold for the range may be boosted by computer.
			; It takes seconds for missile launchers to switch ammo so the range update delay
			; bug in energy weapons should not affect them.
			if ${Entity[${targetID}].Distance} <= ${_shortRangeAmmoRange} && (${This.MissileDamageEfficiency[${TargetID}]} > 0.1)
			{
				return ${shortRangeAmmo}
			}
			elseif ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
			{
				return ${longRangeAmmo}
			}
			else
			{
				return ${shortRangeAmmo}
			}
		}
		elseif ${This.Charge(exists)} && ${This.Charge.Type.Equal[${longRangeAmmo}]}
		{
			if (${Entity[${targetID}].Distance} <= ${Utility.Max[${Math.Calc[${This.Range} * 0.5]}, ${_shortRangeAmmoRange}]}) && \
				(${This.MissileDamageEfficiency[${TargetID}]} > 0.2)
			{
				if  ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
					return ${shortRangeAmmo}
				}
				else
				{
					return ${longRangeAmmo}
				}
			}
			else
			{
				return ${longRangeAmmo}
			}
		}
		else /*no ammo exist or unknown ammo loaded*/
		{
			if ${Entity[${targetID}].Distance} <= ${_shortRangeAmmoRange}
			{
				if ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
				    return ${shortRangeAmmo}
				}
				elseif ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
			    {
				    return ${longRangeAmmo}
			    }
			}
			else
			{
			    ; This mean when range is not cached yet, it will pick long range ammo.
				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
			    {
				    return ${longRangeAmmo}
			    }
				elseif ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
				    return ${shortRangeAmmo}
				}
			}
		}

		This:LogCritical["No configured ammo in cargo!"]
		return ""
	}

	member:string _pickOptimalScriptTrackingComputerScript(int64 targetID)
	{
		if ${targetID.Equal[TARGET_NA]} || !${This._isTargetValid[${targetID}]} || !(${Ship.${WeaponSwitch}.Count} > 0)
		{
			InstructionTargetID:Set[TARGET_NA]
			return ""
		}

		if ${Entity[${targetID}].Distance} > ${Ship.${WeaponSwitch}.OptimalRange}
		{
			; echo need range
			if !${This.Charge.Type(exists)} || ${This.Charge.Type.Equal["Tracking Speed Script"]}
			{
				if ${MyShip.Cargo["Optimal Range Script"].Quantity} > 0
				{
					return "Optimal Range Script"
				}
				; BUG of ISXEVE: UnloadToCargo method is not working
				; elseif ${This.Charge.Type.Equal["Tracking Speed Script"]}
				; {
				; 	return "unload"
				; }
			}
		}
		elseif ${Ship.${WeaponSwitch}.TurretTrackingDecayFactor[${targetID}]} > 0.2 /*roughly 93.3% hit chance*/
		{
			; echo need tracking
			if !${This.Charge.Type(exists)} || ${This.Charge.Type.Equal["Optimal Range Script"]}
			{
				if ${MyShip.Cargo["Tracking Speed Script"].Quantity} > 0
				{
					return "Tracking Speed Script"
				}
				; BUG of ISXEVE: UnloadToCargo method is not working
				; elseif ${This.Charge.Type.Equal["Optimal Range Script"]}
				; {
				; 	return "unload"
				; }
			}
		}

		return ""
	}

	member:string _pickOptimalScriptMissileGuidanceComputerScript(int64 targetID)
	{
		if ${targetID.Equal[TARGET_NA]} || !${This._isTargetValid[${targetID}]} || !(${Ship.ModuleList_MissileLauncher.Count} > 0)
		{
			InstructionTargetID:Set[TARGET_NA]
			return ""
		}

		if (${Ship.ModuleList_MissileLauncher.DamageEfficiency[${targetID}]} < 0.8) && \
			(${Entity[${targetID}].Distance} < ${Math.Calc[${Ship.ModuleList_MissileLauncher.Range} * 0.6]})
		{
			if ${MyShip.Cargo["Missile Precision Script"].Quantity} > 0
			{
				return "Missile Precision Script"
			}
			; BUG of ISXEVE: UnloadToCargo method is not working
			; elseif ${This.Charge.Type.Equal["Tracking Speed Script"]}
			; {
			; 	return "unload"
			; }
		}
		elseif ${MyShip.Cargo["Missile Range Script"].Quantity} > 0
		{
			return "Missile Range Script"
		}

		return ""
	}

	member:string _getDefaultAmmo()
	{
		if ${AmmoOverride.NotNULLOrEmpty} && (${MyShip.Cargo[${AmmoOverride}].Quantity} > 4 || (${This.Charge.Type.Equal[${AmmoOverride}]} && ${This.Charge.Quantity} > 0))
		{
			return ${AmmoOverride}
		}
		if !${Ammo.NotNULLOrEmpty} || (!${MyShip.Cargo[${Ammo}].Quantity} && !${This.Charge.Type.Equal[${Ammo}]})
		{
			return ${This.FallbackAmmo}
		}
		else
		{
			return "${Ammo}"
		}
	}

	member:string _getDefaultLongRangeAmmo()
	{
		if ${AmmoOverride.NotNULLOrEmpty} && (${MyShip.Cargo[${AmmoOverride}].Quantity} > 4 || (${This.Charge.Type.Equal[${AmmoOverride}]} && ${This.Charge.Quantity} > 0))
		{
			return ${AmmoOverride}
		}
		if !${LongRangeAmmo.NotNULLOrEmpty} || (!${MyShip.Cargo[${LongRangeAmmo}].Quantity} && !${This.Charge.Type.Equal[${LongRangeAmmo}]})
		{
			return ${This.FallbackLongRangeAmmo}
		}
		else
		{
			return "${LongRangeAmmo}"
		}
	}
	
	member:string _getDefaultXtraLongRangeAmmo()
	{
		if ${AmmoOverride.NotNULLOrEmpty} && (${MyShip.Cargo[${AmmoOverride}].Quantity} > 4 || (${This.Charge.Type.Equal[${AmmoOverride}]} && ${This.Charge.Quantity} > 0))
		{
			return ${AmmoOverride}
		}
		if !${xtraLongRangeAmmo.NotNULLOrEmpty} || (!${MyShip.Cargo[${xtraLongRangeAmmo}].Quantity} && !${This.Charge.Type.Equal[${xtraLongRangeAmmo}]})
		{
			return ${This.FallbackXtraLongRangeAmmo}
		}
		else
		{
			return "${xtraLongRangeAmmo}"
		}
	}

	method _findAndChangeAmmo(string ammo)
	{
		variable index:item availableAmmos
		This:GetAvailableAmmo[availableAmmos]
		if ${availableAmmos.Used} == 0
		{
			if ${Client.InSpace}
			{
				This:LogCritical["No Ammo available - dreadful - also, annoying"]
			}
			return
		}

		variable iterator availableAmmoIterator
		availableAmmos:GetIterator[availableAmmoIterator]
		if ${availableAmmoIterator:First(exists)}
		do
		{
			if ${ammo.Equal[${availableAmmoIterator.Value.Name}]}
			{
				variable int chargeAmountToLoad
				chargeAmountToLoad:Set[${Utility.Min[${This.MaxCharges}, ${MyShip.Cargo[${ammo}].Quantity}]}]
				This:_changeAmmo[${availableAmmoIterator.Value.ID}, ${chargeAmountToLoad}, "${availableAmmoIterator.Value.Name}"]
				return
			}
		}
		while ${availableAmmoIterator:Next(exists)}
	}

	method _reloadAmmo(string ammo)
	{
		This:_reloadAll
	}

	member:float64 _HPPercentage()
	{
		if !${This.HP(exists)}
		{
			return 0
		}

		variable float64 percentage
		percentage:Set[${Math.Calc[(${This.HP} - ${This.Damage}) / ${This.HP} * 100]}]

		return ${percentage}
	}

	; Return:
	;	TRUE: Toggled something.
	;	FALSE: Did nothing.
	member:bool _toggleOverload()
	{
		; Toggle only once, no retry because even if we can detect whether module is overloaded.
		; We don't want to retry because unlike Activate() and Deactivate() methods, the effect
		; of Toggle() method is undetermined. Retrying may do evil.
		if ${This._HPPercentage} > ${This.OverloadIfHPAbovePercent} && !${_overloadToggledOn}
		{
			_overloadToggledOn:Set[TRUE]
			; Turn on
			This:LogDebug["Turning on overload HP ${This._HPPercentage}% > ${This.OverloadIfHPAbovePercent}%."]
			This:ToggleOverload

			; This:QueueState["Operate", ${_intervalBetweenOperations}]
			return TRUE
		}
		elseif ${This._HPPercentage} <= ${This.OverloadIfHPAbovePercent} && ${_overloadToggledOn}
		{
			_overloadToggledOn:Set[FALSE]
			; Turn off
			This:LogDebug["Turning off overload HP ${This._HPPercentage}% < ${This.OverloadIfHPAbovePercent}%."]
			This:ToggleOverload

			; This:QueueState["Operate", ${_intervalBetweenOperations}]
			return TRUE
		}

		return FALSE
	}

	member:float Range()
	{
		if ${This.TransferRange(exists)}
		{
			return ${This.TransferRange}
		}
		if ${This.ShieldTransferRange(exists)}
		{
			return ${This.ShieldTransferRange}
		}
		if ${This.OptimalRange(exists)}
		{
			if ${This.AccuracyFalloff(exists)}
			{
				return ${Math.Calc[${This.OptimalRange} + ${This.AccuracyFalloff}]}
			}
			return ${This.OptimalRange}
		}
		elseif ${This.ToItem.GroupID.Equal[GROUP_MISSILELAUNCHERRAPIDHEAVY]} || \
			${This.ToItem.GroupID.Equal[GROUP_MISSILELAUNCHER]} || \
			${This.ToItem.GroupID.Equal[GROUP_MISSILELAUNCHERASSAULT]} || \
			${This.ToItem.GroupID.Equal[GROUP_MISSILELAUNCHERBOMB]} || \
			${This.ToItem.GroupID.Equal[GROUP_MISSILELAUNCHERCITADEL]} || \
			${This.ToItem.GroupID.Equal[GROUP_MISSILELAUNCHERCRUISE]} || \
			${This.ToItem.GroupID.Equal[GROUP_MISSILELAUNCHERDEFENDER]} || \
			${This.ToItem.GroupID.Equal[GROUP_MISSILELAUNCHERHEAVY]} || \
			${This.ToItem.GroupID.Equal[GROUP_MISSILELAUNCHERHEAVYASSAULT]} || \
			${This.ToItem.GroupID.Equal[GROUP_MISSILELAUNCHERROCKET]} || \
			${This.ToItem.GroupID.Equal[GROUP_MISSILELAUNCHERTORPEDO]} || \
			${This.ToItem.GroupID.Equal[GROUP_MISSILELAUNCHERSTANDARD]}
		{
			if ${This.Charge(exists)}
			{
				return ${Math.Calc[${This.Charge.MaxFlightTime} * ${This.Charge.MaxVelocity}]}
			}
			elseif ${This._shortRangeAmmoRange} > 1
			{
				return ${This._shortRangeAmmoRange}
			}

			return 50000
		}
	}

	member:string FallbackAmmo()
	{
		switch ${This.ToItem.TypeID}
		{
			case TYPE_MEGA_PULSE_LASER
				return "Conflagration L"
			case TYPE_TORPEDO_LAUNCHER
				return "Scourge Rage Torpedo"
			case TYPE_800MM_REPEATING_CANNON
				return "Hail L"
			case TYPE_XLARGE_ANCILLARY_SHIELD_BOOSTER
				return "Cap Booster 400"
			case TYPE_RAPID_HEAVY_LAUNCHER
				return "Inferno Heavy Missile"
			case TYPE_VORTON_WEAPON
				return "ElectroPunch Ultra L"
			case TYPE_VORTON_WEAPON_MED
				return "ElectroPunch Ultra M"				
		}

		return ""
	}

	member:string FallbackLongRangeAmmo()
	{
		switch ${This.ToItem.TypeID}
		{
			case TYPE_MEGA_PULSE_LASER
				return "Scorch L"
			case TYPE_TORPEDO_LAUNCHER
				return "Scourge Javelin Torpedo"
			case TYPE_800MM_REPEATING_CANNON
				return "Barrage L"
			case TYPE_VORTON_WEAPON
				return "GalvaSurge Condenser Pack M"
			case TYPE_VORTON_WEAPON_MED
				return "GalvaSurge Condenser Pack M"
		}

		return ""
	}
	
	member:string FallbackXtraLongRangeAmmo()
	{
		switch ${This.ToItem.TypeID}
		{
			case TYPE_MEGA_PULSE_LASER
				return "Scorch L"
			case TYPE_TORPEDO_LAUNCHER
				return "Scourge Javelin Torpedo"
			case TYPE_800MM_REPEATING_CANNON
				return "Barrage L"
			case TYPE_VORTON_WEAPON
				return "StrikeSnipe Ultra L"
			case TYPE_VORTON_WEAPON_MED
				return "StrikeSnipe Ultra L"
		}

		return ""
	}

	member:float DamageEfficiency(int64 targetID)
	{
		switch ${This.ToItem.GroupID}
		{
			case GROUP_ENERGYWEAPON
			case GROUP_PROJECTILEWEAPON
			case GROUP_HYBRIDWEAPON
			case GROUP_PRECURSORWEAPON
				return ${This.TurretChanceToHit[${targetID}]}
			case GROUP_MISSILELAUNCHERRAPIDHEAVY
			case GROUP_MISSILELAUNCHER
			case GROUP_MISSILELAUNCHERASSAULT
			case GROUP_MISSILELAUNCHERBOMB
			case GROUP_MISSILELAUNCHERCITADEL
			case GROUP_MISSILELAUNCHERCRUISE
			case GROUP_MISSILELAUNCHERDEFENDER
			case GROUP_MISSILELAUNCHERHEAVY
			case GROUP_MISSILELAUNCHERHEAVYASSAULT
			case GROUP_MISSILELAUNCHERROCKET
			case GROUP_MISSILELAUNCHERTORPEDO
			case GROUP_MISSILELAUNCHERSTANDARD
				return ${This.MissileDamageEfficiency[${targetID}]}
		}

		return 0
	}

;;;;;;;;;;turret
	member:float64 _turretRangeDecayFactor(int64 targetID)
	{
		; Target relative coordinate.
		variable float64 X
		variable float64 Y
		variable float64 Z
		X:Set[${Math.Calc[${Entity[${targetID}].X} - ${MyShip.ToEntity.X}]}]
		Y:Set[${Math.Calc[${Entity[${targetID}].Y} - ${MyShip.ToEntity.Y}]}]
		Z:Set[${Math.Calc[${Entity[${targetID}].Z} - ${MyShip.ToEntity.Z}]}]

		; Distance calculated from coordinate is somewhat 500m larger than Entity.Distance,
		; actually the later one gives the same angular velocity number as shown in the overview tab,
		; But I will take the coordinate one as the difference to chance to hit should be small and won't need to deal with devide by zero error.
		variable float64 targetDistance
		targetDistance:Set[${Math.Distance[${X}, ${Y}, ${Z}, 0, 0, 0]}]

		variable float64 turretOptimalRange
		turretOptimalRange:Set[${This.OptimalRange}]

		variable float64 turretFalloff
		if ${This.AccuracyFalloff} >= 1
		{
			turretFalloff:Set[${This.AccuracyFalloff}]
		}
		else
		{
			turretFalloff:Set[1]
		}

		variable float64 decay
		decay:Set[${Math.Calc[${targetDistance} - ${turretOptimalRange}]}]
		decay:Set[${Utility.Max[0, ${decay}]}]

		variable float64 rangeFactor
		rangeFactor:Set[${Math.Calc[(${decay} / ${turretFalloff}) ^^ 2]}]
		This:LogDebug["rangeFactor: \ao ${turretOptimalRange} ${turretFalloff} ${decay} -> ${rangeFactor}"]

		return ${rangeFactor}
	}

	member:float64 _turretTrackingDecayFactor(int64 targetID)
	{
		; Target relative coordinate and velocity.
		variable float64 X
		variable float64 Y
		variable float64 Z
		variable float64 vX
		variable float64 vY
		variable float64 vZ
		X:Set[${Math.Calc[${Entity[${targetID}].X} - ${MyShip.ToEntity.X}]}]
		Y:Set[${Math.Calc[${Entity[${targetID}].Y} - ${MyShip.ToEntity.Y}]}]
		Z:Set[${Math.Calc[${Entity[${targetID}].Z} - ${MyShip.ToEntity.Z}]}]
		vX:Set[${Math.Calc[${Entity[${targetID}].vX} - ${MyShip.ToEntity.vX}]}]
		vY:Set[${Math.Calc[${Entity[${targetID}].vY} - ${MyShip.ToEntity.vY}]}]
		vZ:Set[${Math.Calc[${Entity[${targetID}].vZ} - ${MyShip.ToEntity.vZ}]}]

		variable float64 dotProduct
		dotProduct:Set[${Math.Calc[${vX} * ${X} + ${vY} * ${Y} + ${vZ} * ${Z}]}]

		; Distance calculated from coordinate is somewhat 500m larger than Entity.Distance,
		; actually the later one gives the same angular velocity number as shown in the overview tab,
		; But I will take the coordinate one as the difference to chance to hit should be small and won't need to deal with devide by zero error.
		variable float64 targetDistance
		targetDistance:Set[${Math.Distance[${X}, ${Y}, ${Z}, 0, 0, 0]}]

		variable float64 norm
		norm:Set[${Math.Calc[${targetDistance} * ${targetDistance}]}]

		; Orthogonal(radical) velocity ratio.
		variable float64 ratio
		ratio:Set[${Math.Calc[${dotProduct} / ${norm}]}]

		; Tangent velocity.
		variable float64 projectionvX
		variable float64 projectionvY
		variable float64 projectionvZ
		projectionvX:Set[${Math.Calc[${vX} - ${ratio} * ${X}]}]
		projectionvY:Set[${Math.Calc[${vY} - ${ratio} * ${Y}]}]
		projectionvZ:Set[${Math.Calc[${vZ} - ${ratio} * ${Z}]}]

		; Tangent velocity scalar.
		variable float64 Vt
		Vt:Set[${Math.Sqrt[${projectionvX} * ${projectionvX} + ${projectionvY} * ${projectionvY} + ${projectionvZ} * ${projectionvZ}]}]

		variable float64 angularVelocity
		angularVelocity:Set[${Math.Calc[${Vt} / ${targetDistance}]}]
		This:LogDebug["Target angular velocity: \ao ${projectionvX} ${projectionvY} ${projectionvZ} -> ${angularVelocity}"]

		; angularVelocity:Set[${Math.Calc[${Vt} / ${Entity[${targetID}].Distance}]}]
		; This:LogDebug[" target angular velocity ver 2: \ao ${projectionvX} ${projectionvY} ${projectionvZ} ->  ${angularVelocity}"]

		variable float64 trackingSpeed
		trackingSpeed:Set[${This.TrackingSpeed}]

		variable float64 targetSignatureRadius
		targetSignatureRadius:Set[${Entity[${targetID}].Radius}]

		variable float64 trackingFactor
		trackingFactor:Set[${Math.Calc[(${angularVelocity} * 40000 / ${trackingSpeed} / ${targetSignatureRadius}) ^^ 2]}]
		This:LogDebug["trackingFactor: \ao ${trackingSpeed} ${targetSignatureRadius} -> ${trackingFactor}"]

		return ${trackingFactor}
	}

	member:float64 TurretChanceToHit(int64 targetID)
	{
		variable float64 trackingFactor
		trackingFactor:Set[${This._turretTrackingDecayFactor[${targetID}]}]

		variable float64 rangeFactor
		rangeFactor:Set[${This._turretRangeDecayFactor[${targetID}]}]

		variable float64 chanceToHit
		chanceToHit:Set[${Math.Calc[0.5 ^^ (${trackingFactor} + ${rangeFactor})]}]

		This:LogDebug["chanceToHit: \ao ${rangeFactor} ${trackingFactor} -> ${chanceToHit}"]

		return ${chanceToHit}
	}

;;;;;;;;;;missile launcher
	member:float64 MissileDamageEfficiency(int64 targetID)
	{
		if !${This.Charge(exists)}
		{
			return 1
		}

		; Temporary workaround for can't get ExplosionRadius and ExplosionVelocity attributes.
		;variable string targetClass
		;targetClass:Set[${NPCData.NPCType[${Entity[${targetID}].GroupID}]}]
		; Avoid using drones against structures which may cause AOE damage when destructed.
		;if ${targetClass.Equal["Frigate"]}
		;{
		;	return 0.05
		;}
		;elseif ${targetClass.Equal["Destroyer"]}
		;{
		;	return 0.1
		;}
		;elseif ${targetClass.Equal["Cruiser"]}
		;{
		;	return 0.4
		;}

		;return 1
		;;; Elusif Note - All problems can be solved with SQL
 		variable float64 targetSignatureRadius
 		targetSignatureRadius:Set[${Entity[${targetID}].Radius}]

 		variable float64 targetVelocity
 		targetVelocity:Set[${Entity[${targetID}].Velocity}]

 		variable float64 missileExplosionRadius
 		missileExplosionRadius:Set[${NPCData.PlayerMissileExplosionRadius[${This.Charge.TypeID}]}]

 		variable float64 missileExplosionVelocity
 		missileExplosionVelocity:Set[${NPCData.PlayerMissileExplosionVelocity[${This.Charge.TypeID}]}]

		;This:LogInfo["torpedo ${This.Charge.Type} ${missileExplosionRadius} ${missileExplosionVelocity} ${This.Charge.MaxVelocity} ${This.Charge.MaxFlightTime}"]
 		variable float64 radiusFactor


 		radiusFactor:Set[${Math.Calc[${targetSignatureRadius} / ${missileExplosionRadius}]}]
		;This:LogInfo["radiusFactor ${radiusFactor}"]
		
 		variable float64 drf
 		drf:Set[${NPCData.PlayerMissileDRF[${This.Charge.TypeID}]}]
		;This:LogInfo["drf ${drf}"]
 		variable float64 velocityFactor
 		if !${targetVelocity.Equal[0]}
 		{
 			velocityFactor:Set[${Math.Calc[(${radiusFactor} * ${missileExplosionVelocity} / ${targetVelocity}) ^^ ${drf}]}]
 		}
 		else
 		{
 			velocityFactor:Set[1]
 		}

		;This:LogInfo["velocityFactor ${velocityFactor}"]
  		variable float64 efficiency
 		efficiency:Set[${Utility.Min[${radiusFactor}, ${velocityFactor}]}]
  		efficiency:Set[${Utility.Min[1, ${efficiency}]}]

 		return ${efficiency}
	}

	;member:float64 _getDRF()
	;{
	;	if ${This.Charge(exists)}
	;	{
	;		if ${This.Charge.Type.Find["Rage XL Torpedo"]}
	;		{
	;			return 0.967
	;		}
	;		elseif ${This.Charge.Type.Find["Javelin XL Torpedo"]}
	;		{
	;			return 1.0
	;		}
	;		elseif ${This.Charge.Type.Find["XL Torpedo"]}
	;		{
	;			return 1.0
	;		}
	;		elseif ${This.Charge.Type.Find["Rage Torpedo"]}
	;		{
	;			return 0.967
	;		}
	;		elseif ${This.Charge.Type.Find["Javelin Torpedo"]}
	;		{
	;			return 0.967
	;		}
	;		elseif ${This.Charge.Type.Find["Torpedo"]}
	;		{
	;			return 0.944
	;		}
	;		else
	;		{
	;			This:LogCritical["drf not implemented ${This.Charge.Type}."]
	;			return 1.0
	;		}
	;	}
	;}

	; We want to reload charge in advance for aucillary shield booster to
	; ensure that we always have more than this charge when engaging gankers.
	; when this value is 3, we can run approximately 5 cycles in 25 seconds before
	; the capacitor is empty. Which is equvilant to 67500 EHP.
	member:int ReloadChargeThreshold()
	{
		switch ${This.ToItem.TypeID}
		{
			case TYPE_XLARGE_ANCILLARY_SHIELD_BOOSTER
				return 3
		}

		return 0
	}

	member:bool IsUsingLongRangeAmmo()
	{
		variable string shortRangeAmmo
		shortRangeAmmo:Set[${This._getDefaultAmmo}]

		if !${This.Charge(exists)} || ${This.Charge.Type.Equal[${shortRangeAmmo}]}
		{
			return FALSE
		}

		return TRUE
	}
}

	; 		elseif ${This.ToItem.GroupID} == GROUP_PRECURSORWEAPON
	; 		{
	; 			if ${Entity[${targetID}].Distance} > 70000 || ${Mission.RudeEwar}
	; 			{
	; 				This:QueueState["_findAndChangeAmmo", 50, "Meson Exotic Plasma L"]
	; 			}

	; 			if ${Entity[${targetID}].Distance} > 50000 && ${Entity[${targetID}].Distance} < 70000 && !${Mission.RudeEwar}
	; 			{
	; 				This:QueueState["_findAndChangeAmmo", 50, "Mystic L"]
	; 			}

	; 			if ${Entity[${targetID}].Distance} > 27000 && ${Entity[${targetID}].Distance} < 50000 && !${Mission.RudeEwar}
	; 			{
	; 				This:QueueState["_findAndChangeAmmo", 50, "Baryon Exotic Plasma L"]
	; 			}

	; 			if ${Entity[${targetID}].Distance} < 27000 && ${Entity[${targetID}].Distance} > 7500 && !${Mission.RudeEwar}

	; 			{
	; 				This:QueueState["_findAndChangeAmmo", 50, "Occult L"]
	; 			}

	; 			if ${Entity[${targetID}].Distance} < 7500 && !${Mission.RudeEwar}

	; 			{
	; 				This:QueueState["_findAndChangeAmmo", 50, "Baryon Exotic Plasma L"]
	; 			}
	; 		}
	;


