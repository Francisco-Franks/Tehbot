objectdef obj_NPCData
{
	variable string SetName = "NPCData"

	variable filepath CONFIG_PATH = "${Script.CurrentDirectory}/data"
	variable string CONFIG_FILE = "NPCData.xml"
	variable settingsetref BaseRef
	; This DB will be the pre-packaged DB. It contains the things we need
	variable sqlitedb NPCInfoDB
	; Query we will be using for our NPC Data
	variable sqlitequery GetNPCInfo
	; Don't know if we will need multiples queries, tbh.
	variable sqlitequery GetTypeIDByName
	
	
	
	method Initialize()
	{
		LavishSettings[NPCData]:Clear
		LavishSettings:AddSet[NPCData]

		if ${CONFIG_PATH.FileExists["${CONFIG_FILE}"]}
		{
			LavishSettings[NPCData]:Import["${CONFIG_PATH}/${CONFIG_FILE}"]
		}
		BaseRef:Set[${LavishSettings[NPCData].FindSet[NPCTypes]}]

		Logger:Log["Configuration", " ${This.SetName}: Initialized", "-g"]
		
		NPCInfoDB:Set[${SQLite.OpenDB["NPCInfoDB","${Script.CurrentDirectory}/Data/NPCInfoDB.sqlite"]}]
		
		
	}

	method Shutdown()
	{
		LavishSettings[NPCData]:Clear
		NPCInfoDB:Close
	}


	; GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=25085 AND attributeID=416;"]}]
	;echo ${GetNPCInfo.GetFieldValue["value",float64]}
	
	;;; I am going to subvert this object for my new purposes. Within this object we will be using an SQL DB with every(I think) NPC TypeID and every
	;;; dogma (attribute) associated with that type ID. We will be able to do cool stuff such as:
	;;; Know exactly where an NPC wants to orbit you at. Except for some of the newer enemies, they don't play by those rules.
	;;; Know how fast an NPC will be moving, in that orbit. With or without MWD.
	;;; Know what kinds of EWAR an NPC will use.
	;;; Know what kinds of self reps an NPC will use.
	;;; Know how much DPS an npc will do, and what the damage type profile will be.
	;;; Know an NPCs effective HP against any damage profile.
	;;; From this information we will be able to derive the following things that matter:
	;;; Should I shoot this enemy now? If I don't will I not be able to later? If I don't will it use some horrible debilitating EWAR against me later?
	;;; How many shots/missiles should this enemy be able to withstand? What will be my expected time to kill?
	;;; Am I better off using precision (missile) ammo?
	;;; Am I better off ignoring this enemy entirely, and just sending drones after it?
	;;; Basically this all boils down to priorities.
	;;; New TargetManager will utilize this information, if I don't get too lazy to implement it. 
	
	;;; Well, time to begin I guess. The following members will be explicitly about the enemies parameters. We will relate them to our own in another section.
	; This member will return a float64, this float64 will be the preferred orbit distance for the NPC. This is attribute 416.
	member:float64 EnemyOrbitDistance(int64 TypeID)
	{
		variable float64 EOD
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=416;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			EOD:Set[${GetNPCInfo.GetFieldValue["value"]}]
			echo ${GetNPCInfo.GetFieldValue["value"]}
			GetNPCInfo:Finalize
			return ${EOD}
		}
		else
		{
			echo TypeID not found.
			return -1
		}
	}
	; This member will return a float64, this float64 will be the maximum velocity for the NPC. This is attribute 37. This is the velocity when it is... MWDing? ABing? Who knows. It goes at this velocity to catch up
	member:float64 EnemyMaximumVelocity(int64 TypeID)
	{
		variable float64 MaxVel
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=37;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MaxVel:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${MaxVel}
		}
		else
		{
			; TypeID not found.
			return -1
		}
	}
	; This member will return a float64, this float64 will be the cruising velocity for the NPC. This is attribute 508. This is the velocity it moves at when it is orbiting. 
	member:float64 EnemyCruiseVelocity(int64 TypeID)
	{
		variable float64 CruiseVel
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=508;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			CruiseVel:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${CruiseVel}
		}
		else
		{
			; TypeID not found.
			return -1
		}
	}
	; This member will return a float64, this float64 will be the UNMODIFIED SIGNATURE RADIUS for the NPC. This is attribute 162. This is what its sig radius is by default. I dont know if NPC mwds change their sig radius, target painters will obv.
	; Probably better off using the actual entity info for sig radius tbh.
	member:float64 EnemySignatureRadius(int64 TypeID)
	{
		variable float64 SigRad
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=162;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			SigRad:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${SigRad}
		}
		else
		{
			; TypeID not found.
			return -1
		}
	}
	;;; Hull Tank of NPC
	; This member will return a float64, this float64 will be the Structure HP for the NPC. This is attribute 9.
	member:float64 EnemyHullHP(int64 TypeID)
	{
		variable float64 HullHP
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=9;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			HullHP:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${HullHP}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Structure EM Resistance for the NPC. This is attribute 113.
	member:float64 EnemyHullEMRes(int64 TypeID)
	{
		variable float64 HullEM
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=113;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			HullEM:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${HullEM}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Structure Explosive Resistance for the NPC. This is attribute 111.
	member:float64 EnemyHullExpRes(int64 TypeID)
	{
		variable float64 HullExp
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=111;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			HullExp:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${HullExp}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Structure Kinetic Resistance for the NPC. This is attribute 109.
	member:float64 EnemyHullKinRes(int64 TypeID)
	{
		variable float64 HullKin
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=109;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			HullKin:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${HullKin}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Structure Thermal Resistance for the NPC. This is attribute 110.
	member:float64 EnemyHullThermRes(int64 TypeID)
	{
		variable float64 HullTherm
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=110;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			HullTherm:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${HullTherm}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	;;; Armor Tank of NPC
	; This member will return a float64, this float64 will be the Armor HP for the npc. This is attribute 265.
	member:float64 EnemyArmorHP(int64 TypeID)
	{
		variable float64 ArmorHP
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=265;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			ArmorHP:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${ArmorHP}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Armor EM Resistance for the NPC. This is attribute 267.
	member:float64 EnemyArmorEMRes(int64 TypeID)
	{
		variable float64 ArmorEM
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=267;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			ArmorEM:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${ArmorEM}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Armor Explosive Resistance for the NPC. This is attribute 268.
	member:float64 EnemyArmorExpRes(int64 TypeID)
	{
		variable float64 ArmorExp
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=268;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			ArmorExp:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${ArmorExp}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Armor Kinetic Resistance for the NPC. This is attribute 269.
	member:float64 EnemyArmorKinRes(int64 TypeID)
	{
		variable float64 ArmorKin
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=269;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			ArmorKin:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${ArmorKin}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Armor Thermal Resistance for the NPC. This is attribute 270.
	member:float64 EnemyArmorThermRes(int64 TypeID)
	{
		variable float64 ArmorTherm
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=270;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			ArmorTherm:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${ArmorTherm}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the expected Armor HP/s the NPC can repair. This will be based on attribute 631 (rep amount), attribute 630 (rep duration, measured in milliseconds), and attribute 638 (chance that the rep will actually occur).
	member:float64 EnemyArmorRepSecond(int64 TypeID)
	{
		variable float64 ArmorReps
		variable float64 RepAmount
		variable float64 RepDuration
		variable float64 RepChance
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=631;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			RepAmount:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=630;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			RepDuration:Set[${Math.Calc[${GetNPCInfo.GetFieldValue["value"]}/1000]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=638;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			RepChance:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		ArmorReps:Set[${Math.Calc[(${RepAmount}/${RepDuration})*${RepChance}]}]
		return ${ArmorReps}
	}
	;;; Shield Tank of NPC
	; This member will return a float64, this float64 will be the Shield HP for the npc. This is attribute 263.
	member:float64 EnemyShieldHP(int64 TypeID)
	{
		variable float64 ShieldHP
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=263;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			ShieldHP:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${ShieldHP}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Shield EM Resistance for the NPC. This is attribute 271.
	member:float64 EnemyShieldEMRes(int64 TypeID)
	{
		variable float64 ShieldEM
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=271;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			ShieldEM:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${ShieldEM}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Shield Explosive Resistance for the NPC. This is attribute 272.
	member:float64 EnemyShieldExpRes(int64 TypeID)
	{
		variable float64 ShieldExp
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=272;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			ShieldExp:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${ShieldExp}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Shield Kinetic Resistance for the NPC. This is attribute 273.
	member:float64 EnemyShieldKinRes(int64 TypeID)
	{
		variable float64 ShieldKin
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=273;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			ShieldKin:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${ShieldKin}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Shield Thermal Resistance for the NPC. This is attribute 274.
	member:float64 EnemyShieldThermRes(int64 TypeID)
	{
		variable float64 ShieldTherm
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=274;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			ShieldTherm:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${ShieldTherm}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Shield HP/s the NPC can repair. This will be based on attribute 637 (rep amount), attribute 636 (rep duration, measured in milliseconds), and attribute 639 (chance that rep will actually occur).
	member:float64 EnemyShieldRepSecond(int64 TypeID)
	{
		variable float64 ShieldReps
		variable float64 RepAmount
		variable float64 RepDuration
		variable float64 RepChance
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=637;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			RepAmount:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=636;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			RepDuration:Set[${Math.Calc[${GetNPCInfo.GetFieldValue["value"]}/1000]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=639;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			RepChance:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		ShieldReps:Set[${Math.Calc[(${RepAmount}/${RepDuration})*${RepChance}]}]
		return ${ShieldReps}
	}
	;;; These following members will be for Offensive EWAR capabilities.
	; This member will return a float64, this float64 will be the Warp DISRUPTOR Distance the NPC uses. This will be based on attribute 103 (range), and attribute  105 (strength, we want this to know if its a simple point or an actual scram [disables mwd])
	; Addendum, certain types of NPCs apparently use an entirely different attribute for this. New NPCs use attributes 2507 (range) and 2509 (strength). 
	member:float64 EnemyWarpDisruptorRange(int64 TypeID)
	{
		variable float64 ScramStrength
		variable float64 ScramRange
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND (attributeID=105 OR attributeID=2509);"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			ScramStrength:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		if ${ScramStrength} < 2
		{
			GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND (attributeID=103 OR attributeID=2507);"]}]
			ScramRange:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${ScramRange}
		}
		else
		{
			; This is a Scram.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Warp SCRAMBLER Distance the NPC uses. This will be based on attribute 103 (range) and attribute 105 (strength, if strength is over 1 then its a scram).
	; Addendum, certain types of NPCs apparently use an entirely different attribute for this. New NPCs use attributes 2507 (range) and 2509 (strength).
	member:float64 EnemyWarpScramblerRange(int64 TypeID)
	{
		variable float64 ScramStrength
		variable float64 ScramRange
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND (attributeID=105 OR attributeID=2509);"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			ScramStrength:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		if ${ScramStrength} >= 2
		{
			GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND (attributeID=103 OR attributeID=2507);"]}]
			ScramRange:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${ScramRange}
		}
		else
		{
			; This is a regular Warp Disruptor.
			return 0
		}
	}
	; This member will return a float64, this float 64 will be the Stasis Webifier range for the NPC. This will be based on attribute 514.
	; Addendum, new NPCs use attribute 2500 for this.
	member:float64 EnemyStasisWebRange(int64 TypeID)
	{
		variable float64 WebRange
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND (attributeID=514 OR attributeID=2500);"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			WebRange:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${WebRange}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the Energy Neutralizer range for the NPC. This will be based on attribute 98. It says optimal, neuts work past optimal, but it doesn't tell me the falloff. So this will have to do.
	member:float64 EnemyEnergyNeutRange(int64 TypeID)
	{
		variable float64 NeutRange
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=98;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NeutRange:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${NeutRange}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the amount of capacitor the NPC eats with neuts. Attribute 97.
	member:float64 EnemyEnergyNeutAmount(int64 TypeID)
	{
		variable float64 NeutAmount
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=97;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NeutAmount:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${NeutAmount}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, this float64 will be the amount of capacitor the NPC eats with neuts PER SECOND. Attribute 97 (amount), attribute 942 (duration), and attribute 931 (chance)
	member:float64 EnemyEnergyNeutAmount(int64 TypeID)
	{
		variable float64 NeutSec
		variable float64 NeutAmount
		variable float64 NeutDuration
		variable float64 NeutChance
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=97;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NeutAmount:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=942;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NeutDuration:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=931;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NeutChance:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		NeutSec:Set[${Math.Calc[(${NeutAmount}/${NeutDuration})*${NeutChance}]}]
		return ${NeutSec}
	}
	; This member will return a bool, this bool indicates if the NPC uses ECM. Attribute 936 (ecm optimal range).
	member:bool EnemyUsesECM(int64 TypeID)
	{
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=936;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			GetNPCInfo:Finalize
			return TRUE
		}
		else
		{
			; TypeID not found.
			return FALSE
		}
	}
	; This member will return a bool, this bool indicates if the NPC uses Target Painting. Attribute 941 (target painter max range).
	member:bool EnemyUsesPainters(int64 TypeID)
	{
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=941;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			GetNPCInfo:Finalize
			return TRUE
		}
		else
		{
			; TypeID not found.
			return FALSE
		}
	}
	; This member will return a bool, this bool indicates if the NPC uses Guidance Disruptors (rare, only used by Abyssal enemies?). Attribute 2512
	member:bool EnemyUsesGuidanceDisruption(int64 TypeID)
	{
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=2512;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			GetNPCInfo:Finalize
			return TRUE
		}
		else
		{
			; TypeID not found.
			return FALSE
		}
	}
	; This member will return a bool, this bool indicates if the NPC uses Tracking Disruptors. Attribute 2516.
	member:bool EnemyUsesTrackingDisruption(int64 TypeID)
	{
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=2516;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			GetNPCInfo:Finalize
			return TRUE
		}
		else
		{
			; TypeID not found.
			return FALSE
		}
	}
	; This member will return a float64, the float64 will be the Range of NPC Sensor Dampeners. Attribute 938 for old NPCs, attribute 2528 for new NPCs.
	member:float64 EnemySensorDampRange(int64 TypeID)
	{
		variable float64 DampRange
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND (attributeID=938 OR attributeID=2528);"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			DampRange:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${DampRange}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return a float64, the float64 will be the Strength of the Sensor Damp. 237 for old NPCs. For new NPCs they use a freakin negative number instead of a .80 or whatever. Attribute 309, we need to make it into a positive decimal.
	member:float64 EnemySensorDampStrength(int64 TypeID)
	{
		variable float64 DampStrength
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=237;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			DampStrength:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=309;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			DampStrength:Set[${Math.Calc[(${GetNPCInfo.GetFieldValue["value"]}+100)/100]}]
			GetNPCInfo:Finalize
		}
		if ${DampStrength} > 0
			return ${DampStrength}
		else
			return 0
	}
	;;; The following members will be for actual damaging Offensive Capabilities. Turrets first.
	; This member will return the Optimal Range for the NPCs turrets. Attribute 54
	member:float64 EnemyTurretOptimalRange(int64 TypeID)
	{
		variable float64 TurretOptimal
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=54;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretOptimal:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${TurretOptimal}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return the Falloff Range for the NPCs turrets. Attribute 158
	member:float64 EnemyTurretFalloffRange(int64 TypeID)
	{
		variable float64 TurretFalloff
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=158;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretFalloff:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${TurretFalloff}
		}
		else
		{
			; TypeID not found.
			return 0
		}
	}
	; This member will return the Tracking Speed for the NPCs turrets. Unfortunately, while old NPCs and new NPCs use the same attribute, 160, the old NPCs have numbers below 1 and new NPCs have numbers much higher
	; new NPCs effectively use player mechanics for calculation.
	; Addendum, it is actually that old NPCs use the old turret tracking calculations. It uses some crap called Optimal Sig Radius, attribute 620.
	member:float64 EnemyTurretTrackingSpeed(int64 TypeID)
	{
		variable float64 OptimalSig
		variable float64 TurretTrackingOld
		variable float64 TurretTracking
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=160;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretTrackingOld:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=620;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			OptimalSig:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		if ${OptimalSig} > 0
		{
			TurretTracking:Set[${Math.Calc[(${TurretTrackingOld}*40000)/${OptimalSig}]}]
			return ${TurretTracking}
		}
		else
			return 0
	}
	; This member will return the Turret EM Damage Alpha for the NPC. Attribute 114 (em damage), attribute 64 (damage multiplier).
	member:float64 EnemyTurretEMDamage(int64 TypeID)
	{
		variable float64 TurretEM
		variable float64 TurretMult
		variable float64 TurretDamage
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=114;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretEM:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=64;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretMult:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		TurretDamage:Set[${Math.Calc[${TurretEM}*${TurretMult}]}]
		if ${TurretDamage} > 0
			return ${TurretDamage}
		else
			return 0
	}
	; This member will return the Turret EM Damage PER SECOND for the NPC. Attribute 114 (em damage), attribute 64 (damage multiplier), attribute 51 (rate of fire).
	member:float64 EnemyTurretEMDPS(int64 TypeID)
	{
		variable float64 TurretEM
		variable float64 TurretMult
		variable float64 TurretROF
		variable float64 TurretDamage
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=114;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretEM:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=64;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretMult:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=51;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretROF:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		if ${TurretROF} > 0
		{
			TurretDamage:Set[${Math.Calc[(${TurretEM}*${TurretMult})/${TurretROF}]}]
			if ${TurretDamage} > 0
				return ${TurretDamage}
			else
				return 0
		}
	}
	; This member will return the Turret Explosive Damage Alpha for the NPC. Attribute 116 (Explosive damage), attribute 64 (damage multiplier).
	member:float64 EnemyTurretExplosiveDamage(int64 TypeID)
	{
		variable float64 TurretExp
		variable float64 TurretMult
		variable float64 TurretDamage
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=116;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretExp:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=64;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretMult:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		TurretDamage:Set[${Math.Calc[${TurretExp}*${TurretMult}]}]
		if ${TurretDamage} > 0
			return ${TurretDamage}
		else
			return 0
	}
	; This member will return the Turret Explosive Damage PER SECOND for the NPC. Attribute 116 (Explosive damage), attribute 64 (damage multiplier), attribute 51 (rate of fire).
	member:float64 EnemyTurretExplosiveDPS(int64 TypeID)
	{
		variable float64 TurretExp
		variable float64 TurretMult
		variable float64 TurretROF
		variable float64 TurretDamage
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=116;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretExp:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=64;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretMult:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=51;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretROF:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		if ${TurretROF} > 0
		{
			TurretDamage:Set[${Math.Calc[(${TurretExp}*${TurretMult})/${TurretROF}]}]
			if ${TurretDamage} > 0
				return ${TurretDamage}
			else
				return 0
		}
	}
	; This member will return the Turret Kinetic Damage Alpha for the NPC. Attribute 117 (Kinetic damage), attribute 64 (damage multiplier).
	member:float64 EnemyTurretKineticDamage(int64 TypeID)
	{
		variable float64 TurretKin
		variable float64 TurretMult
		variable float64 TurretDamage
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=117;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretKin:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=64;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretMult:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		TurretDamage:Set[${Math.Calc[${TurretKin}*${TurretMult}]}]
		if ${TurretDamage} > 0
			return ${TurretDamage}
		else
			return 0
	}
	; This member will return the Turret Kinetic Damage PER SECOND for the NPC. Attribute 117 (Kinetic damage), attribute 64 (damage multiplier), attribute 51 (rate of fire).
	member:float64 EnemyTurretKineticDPS(int64 TypeID)
	{
		variable float64 TurretKin
		variable float64 TurretMult
		variable float64 TurretROF
		variable float64 TurretDamage
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=117;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretKin:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=64;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretMult:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=51;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretROF:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		if ${TurretROF} > 0
		{
			TurretDamage:Set[${Math.Calc[(${TurretKin}*${TurretMult})/${TurretROF}]}]
			if ${TurretDamage} > 0
				return ${TurretDamage}
			else
				return 0
		}
	}
	; This member will return the Turret Thermal Damage Alpha for the NPC. Attribute 118 (Thermal damage), attribute 64 (damage multiplier).
	member:float64 EnemyTurretThermalDamage(int64 TypeID)
	{
		variable float64 TurretTherm
		variable float64 TurretMult
		variable float64 TurretDamage
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=118;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretTherm:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=64;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretMult:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		TurretDamage:Set[${Math.Calc[${TurretTherm}*${TurretMult}]}]
		if ${TurretDamage} > 0
			return ${TurretDamage}
		else
			return 0
	}
	; This member will return the Turret Thermal Damage PER SECOND for the NPC. Attribute 118 (Thermal damage), attribute 64 (damage multiplier), attribute 51 (rate of fire).
	member:float64 EnemyTurretThermalDPS(int64 TypeID)
	{
		variable float64 TurretTherm
		variable float64 TurretMult
		variable float64 TurretROF
		variable float64 TurretDamage
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=118;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretTherm:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=64;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretMult:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=51;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			TurretROF:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		if ${TurretROF} > 0
		{
			TurretDamage:Set[${Math.Calc[(${TurretTherm}*${TurretMult})/${TurretROF}]}]
			if ${TurretDamage} > 0
				return ${TurretDamage}
			else
				return 0
		}
	}
	;;; Missiles now.
	;;; Addendum, apparently NPCs use real missiles with a bunch of modifiers thrown on them. This is going to be messy.
	;;; All of these will basically start off with a check to see if a given target USES missiles, then what kind of missile, then the actual stat modified by the modifiers inherent to the npc. Fuck!
	; This member will return the Explosion Velocity of the enemy Missile, provided I can even decrypt this insanity. Missile type is attribute 507. Explosion Velocity NPC Bonus is 859. Missile Explosion Velocity is 653.
	member:float64 EnemyMissileExplosionVelocity(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 NPCExpVelBonus
		variable float64 MissileExpVel
		variable float64 FinalValue
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=507;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileTypeID:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=859;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCExpVelBonus:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=653;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileExpVel:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		FinalValue:Set[${Math.Calc[${NPCExpVelBonus}*${MissileExpVel}]}]
		return ${FinalValue}
	}
	; This member will return the Explosion Radius of the enemy Missile. Missile type is attribute 507. Explosion Radius NPC Modifier is 858. I have to assume that bonus is a Multiplier, so 1.05 is just Whatever * 1.05.
	; Missile explosion radius is attribute 654
	member:float64 EnemyMissileExplosionRadius(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 NPCExpRadBonus
		variable float64 MissileExpRad
		variable float64 FinalValue
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=507;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileTypeID:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=858;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCExpRadBonus:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=654;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileExpRad:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		FinalValue:Set[${Math.Calc[${NPCExpRadBonus}*${MissileExpRad}]}]
		return ${FinalValue}
	}
	; This member will return the DRF of the NPC's missile.
	; Missile DRF is 1353
	member:float64 EnemyMissileDRF(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 FinalValue
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=507;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileTypeID:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=1353;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			FinalValue:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${FinalValue}
		}
	}
	; This member will return the Missile EM Damage output for the NPC. Missile type is 507, NPC Damage Bonus is 212, Missile EM damage is 114.
	member:float64 EnemyMissileEMDamage(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 NPCMissileDmgBonus
		variable float64 MissileEMDmg
		variable float64 FinalValue
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=507;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileTypeID:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=212;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCMissileDmgBonus:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=114;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileEMDmg:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		FinalValue:Set[${Math.Calc[${NPCMissileDmgBonus}*${MissileEMDmg}]}]
		if ${FinalValue} > 0
			return ${FinalValue}
		else
			return 0
	}
	; This member will return the Missile EM Damage PER SECOND for the NPC. Missile type is 507, NPC Damage Bonus is 212, Missile EM damage is 114, ROF is 506.
	member:float64 EnemyMissileEMDPS(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 NPCMissileDmgBonus
		variable float64 NPCMissileROF
		variable float64 MissileEMDmg
		variable float64 FinalValue
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=507;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileTypeID:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=506;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCMissileROF:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=212;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCMissileDmgBonus:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=114;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileEMDmg:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		if ${NPCMissileROF} > 0
		{
			FinalValue:Set[${Math.Calc[(${NPCMissileDmgBonus}*${MissileEMDmg})/${NPCMissileROF}]}]
			if ${FinalValue} > 0
				return ${FinalValue}
			else
				return 0
		}
		else
			return 0
	}
	; This member will return the Missile Explosive Damage output for the NPC. Missile type is 507, NPC Damage Bonus is 212, Missile Exp damage is 116.
	member:float64 EnemyMissileExplosiveDamage(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 NPCMissileDmgBonus
		variable float64 MissileEMDmg
		variable float64 FinalValue
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=507;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileTypeID:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=212;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCMissileDmgBonus:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=116;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileEMDmg:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		FinalValue:Set[${Math.Calc[${NPCMissileDmgBonus}*${MissileEMDmg}]}]
		if ${FinalValue} > 0
			return ${FinalValue}
		else
			return 0
	}
	; This member will return the Missile Exp Damage PER SECOND for the NPC. Missile type is 507, NPC Damage Bonus is 212, Missile Exp damage is 116, ROF is 506.
	member:float64 EnemyMissileExplosiveDPS(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 NPCMissileDmgBonus
		variable float64 NPCMissileROF
		variable float64 MissileExpDmg
		variable float64 FinalValue
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=507;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileTypeID:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=506;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCMissileROF:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=212;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCMissileDmgBonus:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=116;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileExpDmg:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		if ${NPCMissileROF} > 0
		{
			FinalValue:Set[${Math.Calc[(${NPCMissileDmgBonus}*${MissileExpDmg})/${NPCMissileROF}]}]
			if ${FinalValue} > 0
				return ${FinalValue}
			else
				return 0
		}
		else
			return 0
	}
	; This member will return the Missile Kinetic Damage output for the NPC. Missile type is 507, NPC Damage Bonus is 212, Missile Kinetic damage is 117.
	member:float64 EnemyMissileKineticDamage(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 NPCMissileDmgBonus
		variable float64 MissileEMDmg
		variable float64 FinalValue
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=507;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileTypeID:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=212;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCMissileDmgBonus:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=117;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileEMDmg:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		FinalValue:Set[${Math.Calc[${NPCMissileDmgBonus}*${MissileEMDmg}]}]
		if ${FinalValue} > 0
			return ${FinalValue}
		else
			return 0
	}
	; This member will return the Missile Kinetic Damage PER SECOND for the NPC. Missile type is 507, NPC Damage Bonus is 212, Missile Kinetic damage is 117, ROF is 506.
	member:float64 EnemyMissileKineticDPS(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 NPCMissileDmgBonus
		variable float64 NPCMissileROF
		variable float64 MissileKinDmg
		variable float64 FinalValue
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=507;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileTypeID:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=506;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCMissileROF:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=212;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCMissileDmgBonus:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=117;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileKinDmg:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		if ${NPCMissileROF} > 0
		{
			FinalValue:Set[${Math.Calc[(${NPCMissileDmgBonus}*${MissileKinDmg})/${NPCMissileROF}]}]
			if ${FinalValue} > 0
				return ${FinalValue}
			else
				return 0
		}
		else
			return 0
	}
	; This member will return the Missile Thermal Damage output for the NPC. Missile type is 507, NPC Damage Bonus is 212, Missile Thermal damage is 118.
	member:float64 EnemyMissileThermalDamage(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 NPCMissileDmgBonus
		variable float64 MissileEMDmg
		variable float64 FinalValue
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=507;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileTypeID:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=212;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCMissileDmgBonus:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=118;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileEMDmg:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		FinalValue:Set[${Math.Calc[${NPCMissileDmgBonus}*${MissileEMDmg}]}]
		if ${FinalValue} > 0
			return ${FinalValue}
		else
			return 0
	}
	; This member will return the Missile Thermal Damage PER SECOND for the NPC. Missile type is 507, NPC Damage Bonus is 212, Missile Thermal damage is 118, ROF is 506.
	member:float64 EnemyMissileThermalDPS(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 NPCMissileDmgBonus
		variable float64 NPCMissileROF
		variable float64 MissileKinDmg
		variable float64 FinalValue
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=507;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileTypeID:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		else
		{
			; TypeID not found.
			return 0
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=506;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCMissileROF:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${TypeID} AND attributeID=212;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			NPCMissileDmgBonus:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=118;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileKinDmg:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		if ${NPCMissileROF} > 0
		{
			FinalValue:Set[${Math.Calc[(${NPCMissileDmgBonus}*${MissileKinDmg})/${NPCMissileROF}]}]
			if ${FinalValue} > 0
				return ${FinalValue}
			else
				return 0
		}
		else
			return 0
	}
	;;; Ugh, some enemies can do remote reps, either shield or armour, we should probably figure that out at some point. The following members will be for determining if an NPC does remote reps
	;;; and exactly how strong they will be.
	; This member will return the expected shield repair per second an NPC can put out. 
	;;;Attributes ??? Old NPCS I can't find the attributes for this. Might have to forgo on this one.
	
	;;; OK, it is now time, time to take this information and return some useful members. It is time for Math!
	;;; Unfortunately, due to some wonkiness with isxeve, we can't read the stats off of our missiles other than to see how far they will go.
	;;; Thus, we will need to look up our missile in the DB to get its basic stats and then modify them a bit, but we can't see skill levels
	;;; so we will have to basically just fake goddamn everything. Off we go.
	; This member will return the explosion radius of whatever missile we feed into it.
	member:float64 PlayerMissileExplosionRadius(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 PlayerExpRadBonus
		variable float64 PlayerShipExpRadBonus
		variable float64 MissileExpRad
		variable float64 FinalValue
		

		MissileTypeID:Set[${TypeID}]

		; Going to assume you have Guided Missile Precision 4
		PlayerExpRadBonus:Set[0.8]
		; Golem no have bonus for this
		PlayerShipExpRadBonus:Set[1]
		; If you are in some other kinda ship idgaf, I'll make this use real stats some day whenever Amadeus fixes modulecharge
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=654;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileExpRad:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		FinalValue:Set[${Math.Calc[${PlayerShipExpRadBonus}*${PlayerExpRadBonus}*${MissileExpRad}]}]
		return ${FinalValue}
	}
	; This member will return the explosion velocity of whatever missile we feed into it.
	member:float64 PlayerMissileExplosionVelocity(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 PlayerExpVelBonus
		variable float64 PlayerShipExpVelBonus
		variable float64 MissileExpVel
		variable float64 FinalValue
		

		MissileTypeID:Set[${TypeID}]

		; Going to assume you have Target Nav Prediction 4
		PlayerExpVelBonus:Set[1.4]
		; Going to assume you are in a Golem, with BS 5[obv]
		PlayerShipExpVelBonus:Set[1.25]
		; If you are in some other kinda ship idgaf, I'll make this use real stats some day whenever Amadeus fixes modulecharge.
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=653;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileExpVel:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		FinalValue:Set[${Math.Calc[${PlayerShipExpVelBonus}*${PlayerExpVelBonus}*${MissileExpVel}]}]
		return ${FinalValue}
	}
	; This member will return the approximate expected range of the typeID given.
	member:float64 PlayerMissileMaxRange(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 PlayerFlightTimeBonus
		variable float64 PlayerMaxVelocityBonus
		variable float64 MissileFlightTime
		variable float64 MissileMaxVelocity
		variable float64 FinalValue
		

		MissileTypeID:Set[${TypeID}]
		; These numbers will be lies until I get what I need from amadeus.
		PlayerFlightTimeBonus:Set[2]
		PlayerMaxVelocityBonus:Set[3.5]

		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=281;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileFlightTime:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=37;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			MissileMaxVelocity:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
		}
		FinalValue:Set[${Math.Calc[((${PlayerFlightTimeBonus}*${MissileFlightTime})/1000)*(${PlayerMaxVelocityBonus}*${MissileMaxVelocity})]}]
		return ${FinalValue}
	}
	; This member will return the Damage Reduction Factor for a given input missile typeid. I don't really know what the DRF does.
	member:float64 PlayerMissileDRF(int64 TypeID)
	{
		variable float64 MissileTypeID
		variable float64 FinalValue
		

		MissileTypeID:Set[${TypeID}]

		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${MissileTypeID} AND attributeID=1353;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			FinalValue:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${FinalValue}
		}
		else
			return 1
		
	}
	; This member will return the base EM Damage for an input typeID.
	member:float64 PlayerAmmoEM(int64 TypeID)
	{
		variable float64 AmmoTypeID
		variable float64 FinalValue
		

		AmmoTypeID:Set[${TypeID}]

		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${AmmoTypeID} AND attributeID=114;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			FinalValue:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${FinalValue}
		}
		else
			return 0
	}
	; This member will return the base Exp Damage for an input typeID.
	member:float64 PlayerAmmoExp(int64 TypeID)
	{
		variable float64 AmmoTypeID
		variable float64 FinalValue
		

		AmmoTypeID:Set[${TypeID}]

		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${AmmoTypeID} AND attributeID=116;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			FinalValue:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${FinalValue}
		}
		else
			return 0
	}
	; This member will return the base Kin Damage for an input typeID.
	member:float64 PlayerAmmoKin(int64 TypeID)
	{
		variable float64 AmmoTypeID
		variable float64 FinalValue
		

		AmmoTypeID:Set[${TypeID}]

		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${AmmoTypeID} AND attributeID=117;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			FinalValue:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${FinalValue}
		}
		else
			return 0
	}
	; This member will return the base Therm Damage for an input typeID.
	member:float64 PlayerAmmoTherm(int64 TypeID)
	{
		variable float64 AmmoTypeID
		variable float64 FinalValue
		

		AmmoTypeID:Set[${TypeID}]

		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${AmmoTypeID} AND attributeID=118;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			FinalValue:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${FinalValue}
		}
		else
			return 0
	}
	; This member will return the Tracking speed bonus/penalty for an input typeID.
	member:float64 PlayerTrackingMult(int64 TypeID)
	{
		variable float64 AmmoTypeID
		variable float64 FinalValue
		

		AmmoTypeID:Set[${TypeID}]

		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${AmmoTypeID} AND attributeID=244;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			FinalValue:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${FinalValue}
		}
		else
			return 1
	}
	; This member will return the Range bonus/penalty for an input typeID.
	member:float64 PlayerRangeMult(int64 TypeID)
	{
		variable float64 AmmoTypeID
		variable float64 FinalValue
		

		AmmoTypeID:Set[${TypeID}]

		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${AmmoTypeID} AND attributeID=120;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			FinalValue:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${FinalValue}
		}
		else
			return 1
	}
	
	;;; Next up, derived information about NPC defenses, so that we can use those numbers for comparison elsewhere.
	; This member will return the Effective EM HP for the enemy, considering ALL of their defense layers.
	member:float64 EnemyEMEHP(int64 TypeID, string Layer)
	{
		variable float64 FinalValue
		variable float64 StructEHP
		variable float64 ArmorEHP
		variable float64 ShieldEHP
		
		if ${Layer.Equals["Struct"]} || ${Layer.Equals["All"]} && ${This.EnemyHullHP[${TypeID}]} > 0
		{
			StructEHP:Set[${Math.Calc[${This.EnemyHullHP[${TypeID}]}*${This.EnemyHullEMRes[${TypeID}]}]}]
			if !${Layer.Equals["All"]}
				return ${StructEHP}
		}
		if (${Layer.Equals["Armor"]} || ${Layer.Equals["All"]}) && ${This.EnemyArmorHP[${TypeID}]} > 0
		{
			ArmorEHP:Set[${Math.Calc[${This.EnemyArmorHP[${TypeID}]}*${This.EnemyArmorEMRes[${TypeID}]}]}]
			if !${Layer.Equals["All"]}
				return ${ArmorEHP}
		}
		if (${Layer.Equals["Shield"]} || ${Layer.Equals["All"]}) && ${This.EnemyShieldHP[${TypeID}]} > 0
		{
			ShieldEHP:Set[${Math.Calc[${This.EnemyShieldHP[${TypeID}]}*${This.EnemyShieldEMRes[${TypeID}]}]}]
			if !${Layer.Equals["All"]}
				return ${ShieldEHP}
		}
		FinalValue:Set[${Math.Calc[${StructEHP}+${ArmorEHP}+${ShieldEHP}]}]
		if ${Layer.Equals["All"]}
			return ${FinalValue}		
	}
	; This member will return the Effective Explosive HP for the enemy, considering ALL of their defense layers.
	member:float64 EnemyExpEHP(int64 TypeID, string Layer)
	{
		variable float64 FinalValue
		variable float64 StructEHP
		variable float64 ArmorEHP
		variable float64 ShieldEHP
		
		if (${Layer.Equals["Struct"]} || ${Layer.Equals["All"]}) && ${This.EnemyHullHP[${TypeID}]} > 0
		{
			StructEHP:Set[${Math.Calc[${This.EnemyHullHP[${TypeID}]}/${This.EnemyHullExpRes[${TypeID}]}]}]
			if !${Layer.Equals["All"]}
				return ${StructEHP}
		}
		if (${Layer.Equals["Armor"]} || ${Layer.Equals["All"]}) && ${This.EnemyArmorHP[${TypeID}]} > 0
		{
			ArmorEHP:Set[${Math.Calc[${This.EnemyArmorHP[${TypeID}]}/${This.EnemyArmorExpRes[${TypeID}]}]}]
			if !${Layer.Equals["All"]}
				return ${ArmorEHP}
		}
		if (${Layer.Equals["Shield"]} || ${Layer.Equals["All"]}) && ${This.EnemyShieldHP[${TypeID}]} > 0
		{
			ShieldEHP:Set[${Math.Calc[${This.EnemyShieldHP[${TypeID}]}/${This.EnemyShieldExpRes[${TypeID}]}]}]
			if !${Layer.Equals["All"]}
				return ${ShieldEHP}
		}
		FinalValue:Set[${Math.Calc[${StructEHP}+${ArmorEHP}+${ShieldEHP}]}]
		if ${Layer.Equals["All"]}
			return ${FinalValue}
	}	
	; This member will return the Effective Kinetic HP for the enemy, considering ALL of their defense layers.
	member:float64 EnemyKinEHP(int64 TypeID, string Layer)
	{
		variable float64 FinalValue
		variable float64 StructEHP
		variable float64 ArmorEHP
		variable float64 ShieldEHP
		
		if (${Layer.Equals["Struct"]} || ${Layer.Equals["All"]}) && ${This.EnemyHullHP[${TypeID}]} > 0
		{
			StructEHP:Set[${Math.Calc[${This.EnemyHullHP[${TypeID}]}/${This.EnemyHullKinRes[${TypeID}]}]}]
			if !${Layer.Equals["All"]}
				return ${StructEHP}
		}
		if (${Layer.Equals["Armor"]} || ${Layer.Equals["All"]}) && ${This.EnemyArmorHP[${TypeID}]} > 0
		{
			ArmorEHP:Set[${Math.Calc[${This.EnemyArmorHP[${TypeID}]}/${This.EnemyArmorKinRes[${TypeID}]}]}]
			if !${Layer.Equals["All"]}
				return ${ArmorEHP}
		}
		if (${Layer.Equals["Shield"]} || ${Layer.Equals["All"]}) && ${This.EnemyShieldHP[${TypeID}]} > 0
		{
			ShieldEHP:Set[${Math.Calc[${This.EnemyShieldHP[${TypeID}]}/${This.EnemyShieldKinRes[${TypeID}]}]}]
			if !${Layer.Equals["All"]}
				return ${ShieldEHP}
		}
		FinalValue:Set[${Math.Calc[${StructEHP}+${ArmorEHP}+${ShieldEHP}]}]
		if ${Layer.Equals["All"]}
			return ${FinalValue}
	}	
	; This member will return the Effective Thermal HP for the enemy, considering ALL of their defense layers.
	member:float64 EnemyThermEHP(int64 TypeID, string Layer)
	{
		variable float64 FinalValue
		variable float64 StructEHP
		variable float64 ArmorEHP
		variable float64 ShieldEHP
		
		if (${Layer.Equals["Struct"]} || ${Layer.Equals["All"]}) && ${This.EnemyHullHP[${TypeID}]} > 0
		{
			StructEHP:Set[${Math.Calc[${This.EnemyHullHP[${TypeID}]}/${This.EnemyHullThermRes[${TypeID}]}]}]
			if !${Layer.Equals["All"]}
				return ${StructEHP}
		}
		if (${Layer.Equals["Armor"]} || ${Layer.Equals["All"]}) && ${This.EnemyArmorHP[${TypeID}]} > 0
		{
			ArmorEHP:Set[${Math.Calc[${This.EnemyArmorHP[${TypeID}]}/${This.EnemyArmorThermRes[${TypeID}]}]}]
			if !${Layer.Equals["All"]}
				return ${ArmorEHP}
		}
		if (${Layer.Equals["Shield"]} || ${Layer.Equals["All"]}) && ${This.EnemyShieldHP[${TypeID}]} > 0
		{
			ShieldEHP:Set[${Math.Calc[${This.EnemyShieldHP[${TypeID}]}/${This.EnemyShieldThermRes[${TypeID}]}]}]
			if !${Layer.Equals["All"]}
				return ${ShieldEHP}
		}
		FinalValue:Set[${Math.Calc[${StructEHP}+${ArmorEHP}+${ShieldEHP}]}]
		if ${Layer.Equals["All"]}
			return ${FinalValue}
	}
	;;;
	; Need a way to get the type ID by feeding in a name, from another table in this DB.
	member:float64 TypeIDByName(string InputName)
	{
		variable int64 TypeID
		
		GetTypeIDByName:Set[${NPCInfoDB.ExecQuery["Select * FROM invTypes WHERE typeName IS '${InputName}';"]}]
		if ${GetTypeIDByName.NumRows} > 0
		{
			TypeID:Set[${GetTypeIDByName.GetFieldValue["typeID"]}]
			GetTypeIDByName:Finalize
			return ${TypeID}
		}
		else
			return -1
	}
	; This will return the reload time for a given TypeID.
	member:float64 PlayerReloadTime(int64 TypeID)
	{
		variable float64 FinalValue
		variable int64 WeaponTypeID
		
		GetNPCInfo:Set[${NPCInfoDB.ExecQuery["SELECT * FROM dogmaTypeAttributes WHERE typeID=${WeaponTypeID} AND attributeID=1795;"]}]
		if ${GetNPCInfo.NumRows} > 0
		{
			FinalValue:Set[${GetNPCInfo.GetFieldValue["value"]}]
			GetNPCInfo:Finalize
			return ${FinalValue}
		}		
		else
			return -1
	}
	;;;
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;; This was the only thing that was originally here. We will leave it here, I forget what it is even for. Maybe something drone related.
	member:string NPCType(int GroupID)
	{
		variable iterator NPCTypes
		BaseRef:GetSetIterator[NPCTypes]
		if ${NPCTypes:First(exists)}
		{
			do
			{
				if ${NPCTypes.Value.FindSetting[${GroupID}](exists)}
				{
					return ${NPCTypes.Key}
				}
			}
			while ${NPCTypes:Next(exists)}
		}
	}
}
