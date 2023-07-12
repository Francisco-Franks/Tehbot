objectdef obj_Utility
{
	method Initialize()
	{

	}

	member:int EVETimestamp()
	{
		variable string text = ${EVETime.DateAndTime}
		variable string dataText = ${text.Token[1, " "]}
		variable string timeText = ${text.Token[2, " "]}

		variable int year = ${dataText.Token[1, "."]}
		variable int month = ${dataText.Token[2, "."]}
		variable int day = ${dataText.Token[3, "."]}
		variable int hour = ${timeText.Token[1, ":"]}
		variable int minute = ${timeText.Token[2, ":"]}

		variable time timeObj
		timeObj.YearPtr:Set[${Math.Calc[${year} - 1900]}]
		timeObj.MonthPtr:Set[${Math.Calc[${month} - 1]}]
		timeObj.Day:Set[${day}]
		timeObj.Hour:Set[${hour}]
		timeObj.Minute:Set[${minute}]
		; timeObj.Hour:Dec[${delayHours}]
		timeObj:Update
		return ${timeObj.Timestamp.Signed}
	}

	member:bool DowntimeClose()
	{
		variable string timeInDay = ${EVETime.Time}
		variable int hour
		hour:Set[${timeInDay.Token[1, ":"]}]
		variable int minute
		minute:Set[${timeInDay.Token[2, ":"]}]

		if ${hour} == 10 && ${minute} >= 30 && ${minute} <= 59
		{
			return TRUE
		}
		return FALSE
	}

    member:bool Repair()
    {
        if !${Client.InSpace}
        {
            if !${EVEWindow[RepairShop](exists)}
            {
                Logger:Log["Utility", "GetRepairQuote.", LOG_DEBUG]
                MyShip.ToItem:GetRepairQuote
                return TRUE
            }
            else
            {
                if ${EVEWindow[byName, modal](exists)} && ${EVEWindow[byName, modal].Text.Find[Repairing these items]}
                {
                    Logger:Log["Utility", "Repairing these items.", LOG_DEBUG]
                    EVEWindow[byName, modal]:ClickButtonYes
                    Client:Wait[1000]
                    return TRUE
                }
                if ${EVEWindow[byName,"Set Quantity"](exists)}
                {
                    Logger:Log["Utility", "ClickButtonOK.", LOG_DEBUG]
                    EVEWindow[byName,"Set Quantity"]:ClickButtonOK
                    Client:Wait[1000]
                    return TRUE
                }
                if !${EVEWindow[RepairShop].TotalCost.Equal[0]}
                {
                    Logger:Log["Utility", "RepairAlls.", LOG_DEBUG]
                    EVEWindow[RepairShop]:RepairAll
                    return TRUE
                }
            }
        }
        return FALSE
    }

	member:int Min(int a, int b)
	{
		if ${a} < ${b}
		{
			return ${a}
		}

		return ${b}
	}

	member:int Max(int a, int b)
	{
		if ${a} < ${b}
		{
			return ${b}
		}

		return ${a}
	}
	
	member:float64 MinFloat(float64 a, float64 b)
	{
		if ${a} < ${b}
		{
			return ${a}
		}

		return ${b}
	}

	member:float64 MaxFloat(float64 a, float64 b)
	{
		if ${a} < ${b}
		{
			return ${b}
		}

		return ${a}
	}	
}