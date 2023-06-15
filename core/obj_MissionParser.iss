/*
	Mission Data Parser
		Parses HTML Mission information to extract the needed details

	- CyberTech
*/

objectdef obj_MissionParser inherits obj_Logger
{
    ; Opposite to normal experience,
    ; Mission journals can only be stored correctly while initializing variables.
    ; Copying the string with Set[] method will only get a substring with the first few hunderds characters for unknown reason.
    ; Which essentially mean we can't store the mission journal in this object.
    ; Storing AgentName instead is a workaround.
    ; Lavish script is so shit.
    ;
	; variable string MissionJournal
    ;
    ; Must ensure that ${EVEWindow[ByCaption, Agent Conversation - ${AgentName}].ObjectivesHTML.AsJSON} already returns full length
    ; journal BEFORE setting this name or calling any parse function.
    variable string AgentName
	variable string MissionExpiresHex
	variable string MissionName
	variable string Caption

	variable int left = 0
	variable int right = 0

	method Initialize(string Details)
	{
		This.LogLevelBar:Set[${CommonConfig.LogLevelBar}]
		; This.LogLevelBar:Set[LOG_DEBUG]
	}

    member:string EnemyFactionName()
	{
        variable string journalText = ${EVEWindow[ByCaption, Agent Conversation - ${AgentName}].ObjectivesHTML.AsJSON}
        if !${journalText.Find["The following rewards will be yours if you complete this mission"]}
        {
            This:LogCritical["journal length not fully retrieved."]
            return
        }

        variable string factionLogoPrefix = "<img src=\"factionlogo:"

        ; This:LogDebug["journal length ${journalText.Length}"]

        variable int factionID
        variable int left
		left:Set[${journalText.Find[${factionLogoPrefix.AsJSON}]}]
		if ${left} > 0
		{
			;This:LogDebug["DEBUG: Found \"factionlogo\" at ${left}."]
			left:Inc[${factionLogoPrefix.Length}]
            factionID:Set[${journalText.Mid[${left}, 6]}]
		}
		else
		{
            return ""
		}

        This:LogDebug["EnemyFactionName" ${journalText.Length} -- ${factionID} -- ${FactionData.FactionName[${factionID}]}]

        return ${FactionData.FactionName[${factionID}]}
	}

    member:string EnemyDamageToDeal()
	{
        variable string journalText = ${EVEWindow[ByCaption, Agent Conversation - ${AgentName}].ObjectivesHTML.AsJSON}
        if !${journalText.Find["The following rewards will be yours if you complete this mission"]}
        {
            This:LogCritical["journal length not fully retrieved."]
            return
        }

		variable string factionLogoPrefix = "<img src=\"factionlogo:"

        ; This:LogDebug["journal length ${journalText.Length}"]

        variable int factionID
        variable int left
		left:Set[${journalText.Find[${factionLogoPrefix.AsJSON}]}]
		if ${left} > 0
		{
			;This:LogDebug["DEBUG: Found \"factionlogo\" at ${left}."]
			left:Inc[${factionLogoPrefix.Length}]
            factionID:Set[${journalText.Mid[${left}, 6]}]
		}
		else
		{
            return ""
		}

        This:LogDebug["EnemyDamageToDeal" ${journalText.Length} -- ${factionID} -- ${FactionData.FactionDamageToDeal[${factionID}]}]

        return ${FactionData.FactionDamageToDeal[${factionID}]}
	}

	; member:int TypeID()
	; {
	; 	variable int retval = 0

	; 	left:Set[${journalText.Find["<img src=\"typeicon:"]}]
	; 	if ${left} > 0
	; 	{
	; 		;This:LogDebug["DEBUG: Found \"typeicon\" at ${left}."]
	; 		left:Inc[20]
	; 		;This:LogDebug["DEBUG: typeicon substring = ${journalText.Mid[${left},16]}"]
	; 		right:Set[${journalText.Mid[${left},16].Find["\" "]}]
	; 		if ${right} > 0
	; 		{
	; 			right:Dec[2]
	; 			;This:LogDebug["DEBUG: left = ${left}"]
	; 			;This:LogDebug["DEBUG: right = ${right}"]
	; 			;This:LogDebug["DEBUG: string = ${journalText.Mid[${left}, ${right}]}"]
	; 			retval:Set[${journalText.Mid[${left}, ${right}]}]
	; 			This:LogDebug["DEBUG: typeID = ${retval}"]
	; 		}
	; 		else
	; 		{
	; 			This:LogCritical["ERROR: Did not find end of \"typeicon\"!"]
	; 		}
	; 	}
	; 	else
	; 	{
	; 		This:LogInfo["WARNING: Did not find \"typeicon\".  No cargo???"]
	; 	}
	; 	return ${retval}
	; }

	; member:float Volume()
	; {
	; 	variable int retval = 0
	; 	variable string CubicMetreUtf8 = "m³"

	; 	right:Set[${journalText.Find[${CubicMetreUtf8}]}]
	; 	if ${right} > 0
	; 	{
	; 		; This:LogDebug["DEBUG: Found \"${CubicMetreUtf8}\" at ${right}."]
	; 		right:Dec
	; 		left:Set[${journalText.Mid[${Math.Calc[${right}-16]},16].Find[" ("]}]
	; 		if ${left} > 0
	; 		{
	; 			left:Set[${Math.Calc[${right}-16+${left}+1]}]
	; 			right:Set[${Math.Calc[${right}-${left}]}]
	; 			;This:LogDebug["DEBUG: left = ${left}"]
	; 			;This:LogDebug["DEBUG: right = ${right}"]
	; 			;This:LogDebug["DEBUG: string = ${journalText.Mid[${left}, ${right}]}"]
	; 			retval:Set[${journalText.Mid[${left}, ${right}]}]
	; 			This:LogDebug["DEBUG: Volume = ${retval}"]
	; 		}
	; 		else
	; 		{
	; 			This:LogCritical["ERROR: Did not find number before \"${CubicMetreUtf8}\"!"]
	; 		}
	; 	}
	; 	else
	; 	{
	; 		This:LogInfo["WARNING: Did not find \"${CubicMetreUtf8}\".  No cargo???"]
	; 	}

	; 	return ${retval}
	; }

	member:bool IsLowSec()
	{
		variable string journalText = ${EVEWindow[ByCaption, Agent Conversation - ${AgentName}].ObjectivesHTML.AsJSON}
        if !${journalText.Find["The following rewards will be yours if you complete this mission"]}
        {
            This:LogCritical["journal length not fully retrieved."]
            return
        }

        ; This:LogDebug["IsLowSec journal length ${journalText.Length}"]

		if ${journalText.Find["low security system"]}
		{
            This:LogDebug["low sec mission."]
			return TRUE
		}

        return FALSE
	}

    member:bool IsComplete()
	{
		variable string journalText = ${EVEWindow[ByCaption, Agent Conversation - ${AgentName}].ObjectivesHTML.AsJSON}
        if !${journalText.Find["The following rewards will be yours if you complete this mission"]}
        {
            This:LogCritical["journal length not fully retrieved."]
            return
        }

        ; This:LogDebug["IsComplete journal length ${journalText.Length}"]

        variable int left
        variable int right
        variable string mainHeaderPrefix = "subheader><font>"
        left:Set[${journalText.Find[${mainHeaderPrefix}]}]
        variable string missionName
		if ${left} > 0
		{
			left:Inc[${mainHeaderPrefix.Length}]
			right:Set[${journalText.Mid[${left}, 50].Find["<"]}]
			if ${right} > 0
			{
				right:Dec[1]
				missionName:Set[${journalText.Mid[${left}, ${right}]}]
				;This:LogDebug["Mission name: ${missionName}"]
			}
		}

        if !${missionName.NotNULLOrEmpty}
		{
			;This:LogCritical["Failed to parse mission name"]
		}

		variable string checkMarkIcon = "icon:38_193"
        variable string circleMarkIcon = "icon:38_195"
        if ${journalText.Find[${missionName} Objectives Complete]} || \
            ; check mark icon >=2 and
            (${Math.Calc[${journalText.Length} - ${journalText.ReplaceSubstring[${checkMarkIcon}, ""].Length}].Int} >= ${Math.Calc[${checkMarkIcon.Length} * 2].Int} && \
            ; No unfinished targets(circle) or the circle appears before the first check implies that the ship is not docked at the dropoff station.
            (!${journalText.Find[${circleMarkIcon}]} || ${journalText.Find[${circleMarkIcon}]} < ${journalText.Find[${checkMarkIcon}]}))
        {
            This:LogDebug["mission complete."]
			return TRUE
		}

        return FALSE
	}

    member:bool IsOngoing()
	{
		variable string journalText = ${EVEWindow[ByCaption, Agent Conversation - ${AgentName}].ObjectivesHTML.AsJSON}
        if !${journalText.Find["The following rewards will be yours if you complete this mission"]}
        {
            This:LogCritical["journal length not fully retrieved."]
            return
        }

        ; This:LogDebug["IsOngoing journal length ${journalText.Length}"]

        variable int left
        variable int right
        variable string mainHeaderPrefix = "subheader><font>"
        left:Set[${journalText.Find[${mainHeaderPrefix}]}]
        variable string missionName
		if ${left} > 0
		{
			left:Inc[${mainHeaderPrefix.Length}]
			right:Set[${journalText.Mid[${left}, 50].Find["<"]}]
			if ${right} > 0
			{
				right:Dec[1]
				missionName:Set[${journalText.Mid[${left}, ${right}]}]
				This:LogDebug["Mission name: ${missionName}"]
			}
		}

        if !${missionName.NotNULLOrEmpty}
		{
			This:LogCritical["Failed to parse mission name"]
		}

		if !${This.IsComplete} && ${journalText.Find[${missionName} Objectives]}
		{
            This:LogDebug["mission ongoing."]
			return TRUE
		}

        return FALSE
	}

    ; DON'T TOUCH THIS
    ; BUGGY LAVISHSCRIPT STRING SUCH PAIN IN THE ASS
    member:string AquireItem()
	{
        ; Find[] is not case sensitive so it may confuse quantity x with moon index X.
		variable string journalText = ${EVEWindow[ByCaption, Agent Conversation - ${AgentName}].ObjectivesHTML.AsJSON.ReplaceSubstring[" X -", "MOON_10_ESCAPE-"]}
        if !${journalText.Find["The following rewards will be yours if you complete this mission"]}
        {
            This:LogCritical["journal length not fully retrieved."]
            return
        }

        if !${journalText.Find["Acquire these goods:"]}
        {
            return ""
        }

        ; journal example:
        ; <tr valign=middle>
        ;     n
        ;     <td><img src=icon:38_195 size=16></td>
        ;     n
        ;     <td width=32><a href=showinfo:19398><img src=typeicon:19398 width=32 height=32 align=left></a></td>
        ;     n
        ;     <td>Item</td>
        ;     n
        ;     <td>60 x Confiscated Viral Agent (30.0 m³)</td>
        ;     n
        ; </tr>
        variable int left
        variable int right
        variable string itemtd = "<td>Item</td>"

        ; Actually Find[] won't work correctly with those spaces, hopefully this won't affect us with Trim[]
        variable string quantityMark = " x "
        variable string leftParenthesis = " ("

        variable string itemName
        left:Set[${journalText.Find[${itemtd}]}]

        ; Token[] only working with shorter strings.
        if ${left} > 0
        {
            left:Inc[${itemtd.Length}]
            journalText:Set[${journalText.Mid[${left}, 100]}]

            This:LogDebug["slice "${journalText}]
            itemName:Set[${journalText.Token[2, ${quantityMark}].Token[1, ${leftParenthesis}].Trim}]
            This:LogDebug["Item name: ${itemName}"]
        }

        if !${itemName.NotNULLOrEmpty}
		{
			This:LogCritical["Failed to parse item name"]
		}

        return ${itemName}
	}

    ; DON'T TOUCH THIS
    ; BUGGY LAVISHSCRIPT STRING SUCH PAIN IN THE ASS
    member:string DeliverItem()
	{
		variable string journalText = ${EVEWindow[ByCaption, Agent Conversation - ${AgentName}].ObjectivesHTML.AsJSON}
        if !${journalText.Find["The following rewards will be yours if you complete this mission"]}
        {
            This:LogCritical["journal length not fully retrieved."]
            return
        }

        ; Finding longer string doesn't work either...
        variable string grantItemTitle = "Granted Items"
        if !${journalText.Find[${grantItemTitle}]}
        {
            return ""
        }

        ; journal example
        ; n <br>n <br>n <span id=subheader>Granted Items</span>n
        ; <div id=basetext>The following item will be granted to you when the mission is accepted</div>
        ; n
        ; <div>
        ;     <table>
        ;         n n
        ;         <tr valign=middle>
        ;         n
        ;         <td width=36><a href=showinfo:2250><img src=typeicon:2250 width=32 height=32 align=left></a></td>
        ;         n
        ;         <td width=352>1 x Neurowave Pattern Scanner</td>
        ;         n
        ;         </tr>
        ;         n
        ;     </table>
        ; </div>
        variable string itemName
        variable int left
        variable int right

        ; Find[] function won't work correctly with those strings with spaces.
        ; Find[] is not case sensitive so it may confuse quantity x with moon index X.
        journalText:Set[${EVEWindow[ByCaption, Agent Conversation - ${AgentName}].ObjectivesHTML.AsJSON.Replace[" ", "_"].ReplaceSubstring["_X_-", "MOON_10_ESCAPE-"]}]
        variable string quantityIcon = "_x_"
        left:Set[${journalText.Find[${quantityIcon}]}]

        if ${left} > 0
        {
            itemName:Set[${journalText.Mid[${left:Inc[3]}, 50]}]
            This:LogDebug["slice " ${itemName}]

            right:Set[${itemName.Find["<"]}]
            right:Dec[1]

            itemName:Set[${itemName.Left[${right}].Replace["_", " "]}]
            This:LogDebug["Item name: ${itemName}"]
        }

        if !${itemName.NotNULLOrEmpty}
		{
			This:LogCritical["Failed to parse item name"]
		}

        return ${itemName}
	}

	method ParseCaption()
	{
		This.Caption:Set["${amIterator.Value.Name}"]
		left:Set[${This.Caption.Find["u2013"]}]

		if ${left} > 0
		{
			This:LogInfo["WARNING: Mission name contains u2013"]
			This:LogDebug["DEBUG: amIterator.Value.Name = ${amIterator.Value.Name}"]

			This.Caption:Set["${This.Caption.Right[${Math.Calc[${This.Caption.Length} - ${left} - 5]}]}"]

			This:LogDebug["DEBUG: This.Caption = ${This.Caption}"]
		}
	}

	method SaveCacheFile()
	{
		variable file DetailsFile
		DetailsFile:SetFilename["./config/logs/${This.MissionExpiresHex} ${This.MissionName.Replace[",",""]}.html"]

		if ${DetailsFile:Open(exists)}
		{
			DetailsFile:Write["${journalText}"]
			DetailsFile:Close
		}
	}
}