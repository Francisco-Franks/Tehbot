objectdef obj_DimensionalNavigation inherits obj_StateQueue
{
	; A variable to indicate we are in the middle of an MJD procedure (the entire thing beginning to end)
	variable bool MJDInProgress
	; Going to store a timestamp for when we last used our MJD.
	variable int64 LastMJDTime
	; Going to store a timestamp for when we can next use our MJDActivate
	variable int64 NextMJDTime
	; Another timer, when did we begin our align>
	variable int64 BeganAligning
	; Another timer, when did we invoke an MJD
	variable int64 InvokeTimer
	; Bool indicates something has invoked an MJD use
	variable bool MJDInvoked
	; Bool indicates we have actually activated our MJDUsable
	variable bool MJDActivated
	; Bool indicates the jump has actually concluded.
	variable bool JumpCompleted
	
	; Going to store our pre jump coords
	variable float64 PreJumpCoordX
	variable float64 PreJumpCoordY
	variable float64 PreJumpCoordZ
	
	; Going to store our current jump's coords and our current jump's entity. If either.
	variable float64 CurrentJumpCoordX
	variable float64 CurrentJumpCoordY
	variable float64 CurrentJumpCoordZ
	variable int64 CurrentJumpEntityID
	variable bool CurrentJumpReturnTrip
	
	
	method Initialize()
	{
		This[parent]:Initialize
		PulseFrequency:Set[2000]
		;This.NonGameTiedPulse:Set[TRUE]

		This:QueueState["DimensionHub"]


	}

	method Shutdown()
	{
	
		
	}

	;;; This object will be responsible, at first, for enabling me to use the MJD correctly. Using the MJD involves a bunch of 3d math bullshit that I should put into
	;;; and object instead of just doing a one off method or something.
	;;; I would also like to do some other 3d space related crap later, maybe even some LavishNav crap. We'll settle for the MJD stuff for now.
	;;; 
	
	member:bool DimensionHub()
	{
		if !${Client.InSpace} || ${MyShip.ToEntity.Mode} == MOVE_WARPING
			return FALSE
		
		if ${MJDInvoked} && ${This.MJDUsable}
		{
			; Something has invoked an MJD usage. If it can be used and the alignment method was used, we will go to our MJD use state.
			This:InsertState["UsingMJD",1000]
			MJDInvoked:Set[FALSE]
			return TRUE
		}
			
	
		return FALSE
	}
	
	; This state is where we wait for our MJD alignment, active the MJD, wait for the spool up and landing, and leave when we are done.
	member:bool UsingMJD()
	{
		echo DEBUG DEBUG DEBUG DIMENSIONAL USING MJD STATE START
		if !${Client.InSpace}
		{
			; I have absolutely no idea what set of circumstances could get you here but whatever.
			This:InsertState["DimensionHub",5000]
			return TRUE	
		}
		if ${This.AreWeAligned[${CurrentJumpCoordX},${CurrentJumpCoordY},${CurrentJumpCoordZ},${CurrentJumpEntityID}]} && !${MJDActivated}
		{
			LastMJDTime:Set[${LavishScript.RunningTime}]
			; I think this is a 40 secondish cooldown? Activation + cooldown thing if your skills aren't horrendous.
			NextMJDTime:Set[${Math.Calc[${LavishScript.RunningTime} + 45000]}]
			; At this point either our aligning is complete or we don't need to align to anything.
			PreJumpCoordX:Set[${MyShip.ToEntity.X}]
			PreJumpCoordY:Set[${MyShip.ToEntity.Y}]
			PreJumpCoordZ:Set[${MyShip.ToEntity.Z}]
			
			;Ship.ModuleList_MJD:ActivateAll
			MyShip.Module[${Ship.ModuleList_MJD.ModuleID.Get[1]}]:Activate
			
			This:InsertState["SpoolupWait",2000]
			return TRUE
		}
		return FALSE
	}
	
	; Need to make another state for the wait and cleanup after activation
	member:bool SpoolupWait()
	{
		if ${Ship.ModuleList_MJD.ActiveCount} > 0
			return FALSE
		else
			JumpCompleted:Set[TRUE]

		if ${JumpCompleted}
		{
			echo DEBUG DEBUG DIMENSIONAL DOES JUMPCOMPLETED EVEN TRIGGER
			; Jump is complete.
			MJDInProgress:Set[FALSE]
			CurrentJumpCoordX:Set[0]
			CurrentJumpCoordY:Set[0]
			CurrentJumpCoordZ:Set[0]
			CurrentJumpEntityID:Set[0]
			MJDActivated:Set[FALSE]
			This:InsertState["DimensionHub",5000]
			return TRUE	
		}
		; If it has been 75 seconds and we haven't completed the jump, something has probably gone wrong.
		if ${Math.Calc[${LavishScript.RunningTime}-${LastMJDTime}]} > 75000
		{
			MJDInProgress:Set[FALSE]
			CurrentJumpCoordX:Set[0]
			CurrentJumpCoordY:Set[0]
			CurrentJumpCoordZ:Set[0]
			CurrentJumpEntityID:Set[0]
			MJDActivated:Set[FALSE]
			This:InsertState["DimensionHub",5000]
			return TRUE			
		}	
		return FALSE
	}
	
	; This method will be called from mainmodes/minimodes to invoke the usage of a MJD.
	; This will entail : Checking to see that we actually have an MJD. Making sure it is actually usable at this moment. Recording the position we had before activation, recording the position we have after activation (to ensure we actually moved).
	; We will have arguments, a set of 3d coordinates that we are trying to reach (or a 0,0,0 coord indicates we aren't trying to reach anything specific).
	; An entity ID will indicate we are trying to MJD towards a specific entity. A bool to indicate whether we want to go TOWARDS a thing or AWAY from it, which will be ignored for coordinate specific jumps.
	method InvokeMJD(float64 TargetX, float64 TargetY, float64 TargetZ, int64 EntityID, bool JumpAway)
	{
		; If we aren't in space, return. If the MJD isn't usable, return.
		if !${Client.InSpace} || ${MJDInProgress}
			return
			
		MJDInProgress:Set[TRUE]
		; 100 seconds is about as long as this entire process can ever take.
		InvokeTimer:Set[${Math.Calc[${LavishScript.RunningTime}+10000]}]
		; Ok what are we jumping towards? If anything?
		if (${TargetX} == 0 && ${TargetY} == 0 && ${TargetZ} == 0) && ${EntityID} == 0
		{
			; We are just jumping, it doesn't matter towards what.
			CurrentJumpCoordX:Set[0]
			CurrentJumpCoordY:Set[0]
			CurrentJumpCoordZ:Set[0]
			CurrentJumpEntityID:Set[0]
			
		}
		elseif (${TargetX} != 0 && ${TargetY} != 0 && ${TargetZ} != 0)
		{
			; We are jumping towards a specific coordinate. This won't work unless amadeus can get me a way to fly towards an arbitrary point.
			CurrentJumpCoordX:Set[${TargetX}]
			CurrentJumpCoordY:Set[${TargetY}]
			CurrentJumpCoordZ:Set[${TargetZ}]
			CurrentJumpEntityID:Set[0]			
		}
		elseif ${EntityID} != 0
		{
			; Our MJD involves a specific entity. If we are jumping away, we keep at range it with a 1,000 to 2,000 km distance which will force us away from it. This might be dangerous to do, but you only live twice.
			; If we are not jumping away, then we just 
			CurrentJumpCoordX:Set[0]
			CurrentJumpCoordY:Set[0]
			CurrentJumpCoordZ:Set[0]
			CurrentJumpEntityID:Set[${EntityID}]
			if !${JumpAway}
			{
				BeganAligning:Set[${Math.Calc[${LavishScript.RunningTime} + 5000]}]
				Entity[${EntityID}]:AlignTo
			}
			else
				Entity[${EntityID}]:KeepAtRange[${Math.Calc[${Math.Rand[1000000]}+1000000]}]
		}
		
		MJDInvoked:Set[TRUE]
	}
	
	
	; This member will return whether our MJD is currently able to be used. Are we scrammed? Is the MJD cooling down still? Are we bastioned? 
	member:bool MJDUsable()
	{
		variable index:jammer attackers
		variable iterator attackerIterator
		Me:GetJammers[attackers]
		attackers:GetIterator[attackerIterator]
		if ${attackerIterator:First(exists)}
		do
		{
			if ${jamsIterator.Value.Lower.Find["scram"]}
			{
				; We're being scrammed, no MJD
				return FALSE
			}
		}
		while ${attackerIterator:Next(exists)}
		if ${Ship.RegisteredModule.Element[${Ship.ModuleList_Siege.ModuleID.Get[1]}].IsActive}
		{
			; We're bastioned, no MJD
			return FALSE
		}
		; I don't know if this is the correct member. Might just make sure we don't call the method more than once every minute.
		if ${Ship.RegisteredModule.Element[${Ship.ModuleList_MJD.ModuleID.Get[1]}].IsReloading}
		{
			; The MJD is on cooldown or whatever
			return FALSE
		}	
		; Otherwise its true.
		return TRUE
	}
	
	; This member will be used to tell whether we are aligned towards a specific target or coordinate (maybe).
	member:bool AreWeAligned(float64 TargetX, float64 TargetY, float64 TargetZ, int64 EntityID)
	{
		if ${EntityID} != 0
		{	
			; This is going to be a little crude but maybe it will work.
			if ${BeganAligning} < ${LavishScript.RunningTime}
				return TRUE
		}
		elseif (${TargetX} != 0 && ${TargetY} != 0 && ${TargetZ} != 0)
		{
		
		}
		else
			return TRUE
	}
	
	
}
