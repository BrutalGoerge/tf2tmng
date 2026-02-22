/************************************************************************
*************************************************************************
gScramble autoscramble settings (Modernized)
Description:
	Auto-sramble logic for the gscramble addon
*************************************************************************
*************************************************************************/

stock bool ScrambleCheck()
{
	if (g_bScrambleNextRound)
	{
		return true;
	}
	
	if (!g_iLastRoundWinningTeam)
	{
		return false;
	}

	bool bOkayToCheck = false;
	// Always respect the minimum player count to prevent spam-scrambling empty servers
	if (g_iVoters >= cvar_MinAutoPlayers.IntValue)
	{
		if (g_RoundState == bonusRound)
		{
			g_RoundState = roundNormal;
			
			// If set to force every round, bypass the sequential scramble block
			if (cvar_AutoScrambleEveryRound.IntValue > 0)
			{
				bOkayToCheck = true;
			}
			else if (g_bNoSequentialScramble)
			{
				if (!g_bScrambledThisRound)
				{
					bOkayToCheck = true;
				}
			}
			else
			{
				bOkayToCheck = true;
			}
		}
	}
	
	if (bOkayToCheck)
	{
		bool forceEveryRound = false;
		
		// Ensure an admin didn't manually cancel the upcoming scramble via sm_cancel
		// AND ensure that gs_autoscramble is actually set to 1!
		if (!g_bScrambleOverride && g_bAutoScramble)
		{
			int everyRound = cvar_AutoScrambleEveryRound.IntValue;
			if (everyRound == 1 || (everyRound == 2 && g_bWasFullRound))
			{
				forceEveryRound = true;
			}
		}
		
		// Trigger if forced by the new CVar, OR if the normal winstreak/imbalance checks fail
		if (forceEveryRound || WinStreakCheck(g_iLastRoundWinningTeam) || (!g_bScrambleOverride && g_bAutoScramble && AutoScrambleCheck(g_iLastRoundWinningTeam)))
		{
			if (cvar_AutoscrambleVote.BoolValue)
			{
				StartScrambleVote(g_iDefMode, 15);
				return false;
			}
			else		
			{			
				return true;
			}
		}		
	}
	return false;
}

stock bool WinStreakCheck(int winningTeam)
{
	if (g_bScrambleNextRound || !g_bWasFullRound)
	{
		return false;
	}
	
	if (cvar_AutoScrambleRoundCount.BoolValue && g_iRoundTrigger == g_iCompleteRounds)
	{
		if (!g_bSilent)
			PrintToChatAll("\x01\x04[SM]\x01 %t", "RoundMessage");
		LogAction(0, -1, "Round limit reached");
		return true;
	}
	
	if (!cvar_AutoScrambleWinStreak.BoolValue)
	{
		return false;
	}
	
	if (winningTeam == TEAM_RED)
	{
		if (g_aTeams[iBluWins] >= 1)
		{
			g_aTeams[iBluWins] = 0;	
		}
		
		g_aTeams[iRedWins]++;
		if (g_aTeams[iRedWins] >= cvar_AutoScrambleWinStreak.IntValue)
		{
			if (!g_bSilent)
				PrintToChatAll("\x01\x04[SM]\x01 %t", "RedStreak");
			LogAction(0, -1, "Red win limit reached");
			return true;
		}
	}
	
	if (winningTeam == TEAM_BLUE)
	{
		if (g_aTeams[iRedWins] >= 1)
		{
			g_aTeams[iRedWins] = 0;
		}
		
		g_aTeams[iBluWins]++;
		
		if (g_aTeams[iBluWins] >= cvar_AutoScrambleWinStreak.IntValue)
		{
			if (!g_bSilent)
				PrintToChatAll("\x01\x04[SM]\x01 %t", "BluStreak");
			LogAction(0, -1, "Blu win limit reached");
			return true;
		}
	}
	
	return false;
}

stock void StartScrambleDelay(float delay = 5.0, bool respawn = false, e_ScrambleModes mode = invalid)
{
	if (g_hScrambleDelay != null)
	{
		KillTimer(g_hScrambleDelay);
		g_hScrambleDelay = null;
	}
	
	if (mode == invalid)
	{
		mode = view_as<e_ScrambleModes>(cvar_SortMode.IntValue);
	}
	
	DataPack data;
	g_hScrambleDelay = CreateDataTimer(delay, timer_ScrambleDelay, data, TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
	data.WriteCell(respawn);
	data.WriteCell(view_as<int>(mode));
	
	if (delay == 0.0)
	{
		delay = 1.0;	
	}
	
	if (delay >= 2.0)
	{
		PrintToChatAll("\x01\x04[SM]\x01 %t", "ScrambleDelay", RoundFloat(delay));
		if (g_RoundState != bonusRound)
		{	
			EmitSoundToAll(EVEN_SOUND, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
			CreateTimer(1.7, TimerStopSound);
		}
	}
}

public Action timer_AfterScramble(Handle timer, any spawn)
{
	int iEnt = -1;
	
	while ((iEnt = FindEntityByClassname(iEnt, "tf_ammo_pack")) != -1)
	{
		AcceptEntityInput(iEnt, "Kill");
	}	
	
	TF2_RemoveRagdolls();
	if (spawn)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsValidTeam(i))
			{
				if (!IsPlayerAlive(i))
				{
					TF2_RespawnPlayer(i);
				}
				
				if (TF2_GetPlayerClass(i) == TFClass_Unknown)
				{
					TF2_SetPlayerClass(i, TFClass_Scout);
				}
			}
		}
	}
	
	if (GetTime() - g_iRoundStartTime <= 3)
	{
		return Plugin_Handled;
	}
	
	if (g_RoundState == setup && cvar_SetupCharge.BoolValue)	
	{
		LogAction(0, -1, "Filling up medic cannons due to setting");
		for (int i= 1; i<=MaxClients; i++)
		{
			if (IsClientInGame(i) && IsValidTeam(i))
			{
				TFClassType class = TF2_GetPlayerClass(i);
				
				if (class == TFClass_Medic)
				{
					int index = GetPlayerWeaponSlot(i, 1);
					if (index)
					{
						char sClass[33];
						GetEntityNetClass(index, sClass, sizeof(sClass));
						
						if (StrEqual(sClass, "CWeaponMedigun", true))
						{
							SetEntPropFloat(index, Prop_Send, "m_flChargeLevel", 1.0);	
						}
					}
				}		
			}
		}
	}
	return Plugin_Handled;
}

bool AutoScrambleCheck(int winningTeam)
{
	if (g_bFullRoundOnly && !g_bWasFullRound)
	{
		return false;
	}
	
	if (g_bKothMode)
	{
		if (!g_bRedCapped || !g_bBluCapped)
		{
			char team[4];
			g_bRedCapped ? (team = "BLU") : (team = "RED");
			if (!g_bSilent)
				PrintToChatAll("\x01\x04[SM]\x01 %t", "NoCapMessage", team);
			LogAction(0, -1, "%s did not cap a point on KOTH", team);
			return true;
		}
	}
	
	int totalFrags = g_aTeams[iRedFrags] + g_aTeams[iBluFrags];
	int losingTeam = winningTeam == TEAM_RED ? TEAM_BLUE : TEAM_RED;
	int dominationDiffVar = cvar_DominationDiff.IntValue;
	
	if (dominationDiffVar && totalFrags > 20)
	{
		int winningDoms = TF2_GetTeamDominations(winningTeam);
		int losingDoms = TF2_GetTeamDominations(losingTeam);
		if (winningDoms > losingDoms)
		{
			int teamDominationDiff = RoundFloat(FloatAbs(float(winningDoms) - float(losingDoms)));
			if (teamDominationDiff >= dominationDiffVar)
			{
				LogAction(0, -1, "domination difference detected");
				if (!g_bSilent)
					PrintToChatAll("\x01\x04[SM]\x01 %t", "DominationMessage");
				return true;
			}	
		}
	}
	float iDiffVar = cvar_AvgDiff.FloatValue;
	if (totalFrags > 20 && iDiffVar > 0.0 && GetAvgScoreDifference(winningTeam) >= iDiffVar)
	{
		LogAction(0, -1, "Average score diff detected");
		if (!g_bSilent)
			PrintToChatAll("\x01\x04[SM]\x01 %t", "RatioMessage");
		return true;
	}
	
	int winningFrags = winningTeam == TEAM_RED ? g_aTeams[iRedFrags] : g_aTeams[iBluFrags];
	int losingFrags	= winningTeam == TEAM_RED ? g_aTeams[iBluFrags] : g_aTeams[iRedFrags];
	float ratio = float(winningFrags) / float(losingFrags);
	int iSteamRollVar = cvar_Steamroll.IntValue;
	int roundTime = GetTime() - g_iRoundStartTime;
	
	if (iSteamRollVar && winningFrags > losingFrags && iSteamRollVar >= roundTime && ratio >= cvar_SteamrollRatio.FloatValue)
	{
		int minutes = iSteamRollVar / 60;
		int seconds = iSteamRollVar % 60;
		if (!g_bSilent)
			PrintToChatAll("\x01\x04[SM]\x01 %t", "WinTime", minutes, seconds);
		LogAction(0, -1, "steam roll detected");
		return true;
	}
	
	float iFragRatioVar = cvar_FragRatio.FloatValue;
	
	if (totalFrags > 20 && winningFrags > losingFrags && iFragRatioVar > 0.0)	
	{		
		if (ratio >= iFragRatioVar)
		{
			if (!g_bSilent)
				PrintToChatAll("\x01\x04[SM]\x01 %t", "FragDetection");
			LogAction(0, -1, "Frag ratio detected");
			return true;			
		}
	}
	
	return false;
}

public Action Timer_ScrambleSound(Handle timer)
{
	EmitSoundToAll(SCRAMBLE_SOUND, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
	return Plugin_Handled;
}

public Action timer_ScrambleDelay(Handle timer, any data)
{
	g_hScrambleDelay = null;
	g_bScrambleNextRound = false;

	if (cvar_OneScramblePerRound.BoolValue)
	{
		g_bScrambledThisRound = true;
	}
	
	ResetPack(data);
	int respawn = ReadPackCell(data);
	e_ScrambleModes scrambleMode = view_as<e_ScrambleModes>(ReadPackCell(data));
		
	g_aTeams[iRedWins] = 0;
	g_aTeams[iBluWins] = 0;
	g_aTeams[bImbalanced] = false;	
	
	if (g_bPreGameScramble)
	{
		scrambleMode = random;
	}
	else
	{
		if (scrambleMode == randomSort)
		{
			int RandomArr[14];
			int iSelection;
			for (int i=0; i < sizeof(RandomArr); i++)
			{
				RandomArr[i] = GetRandomInt(0,100);
			}
			for (int i=0; i < sizeof(RandomArr); i++)
			{
				if (RandomArr[i] > iSelection)
				{
					iSelection = RandomArr[i];
				}
			}
			scrambleMode = view_as<e_ScrambleModes>(iSelection);
		}
	}
	ScramblePlayers(scrambleMode);
	
	CreateTimer(1.0, Timer_ScrambleSound);
	DelayPublicVoteTriggering(true);
	bool spawn = false;
	
	if (respawn || g_bPreGameScramble)
	{
		spawn = true;
	}
	
	CreateTimer(0.1, timer_AfterScramble, spawn, TIMER_FLAG_NO_MAPCHANGE);	
	if (g_bPreGameScramble && !g_bSilent)
	{
		PrintToChatAll("\x01\x04[SM]\x01 %t", "PregameScrambled");
		g_bPreGameScramble = false;
	}
	else
	{
		if (!g_bSilent)
			PrintToChatAll("\x01\x04[SM]\x01 %t", "Scrambled");		
	}
	
	if (g_bIsTimer && g_RoundState == setup && cvar_SetupRestore.BoolValue)
	{
		TF2_ResetSetup();
	}
	
	FireScrambleEvent();
	return Plugin_Handled;
}

void FireScrambleEvent()
{
	Event event = CreateEvent("teamplay_alert");
	event.SetInt("alert_type", 0);
	event.Fire();
}
	
stock void PerformTopSwap()
{
	g_bBlockDeath = true;
	int iTeam1 = GetTeamClientCount(TEAM_RED);
	int iTeam2 = GetTeamClientCount(TEAM_BLUE);
	int iSwaps = cvar_TopSwaps.IntValue;
	int iArray1[MAXPLAYERS+1][2];
	int iArray2[MAXPLAYERS+1][2];
	int iCount1, iCount2;
	
	if (iSwaps > iTeam1 || iSwaps > iTeam2)
	{
		if (iTeam1 > iTeam2)
		{
			iSwaps = iTeam2 / 2;
		}
		else
		{
			iSwaps = iTeam1 / 2;
		}
	}
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsValidTarget(i))
		{
			if (GetClientTeam(i) == TEAM_RED)
			{
				iArray1[iCount1][0] = i;
				iArray1[iCount1][1] = RoundFloat(GetClientScrambleScore(i, score));
				iCount1++;
			}
			else if (GetClientTeam(i) == TEAM_BLUE)
			{
				iArray2[iCount2][0] = i;
				iArray2[iCount2][1] = RoundFloat(GetClientScrambleScore(i, score));
				iCount2++;
			}
		}
	}
	if (!iCount1 || !iCount2)
	{
		return;
	}
	SortCustom2D(iArray1, iCount1, SortIntsDesc);
	SortCustom2D(iArray2, iCount2, SortIntsDesc);
	
	for (int i = 0; i < iSwaps; i++)
	{		
		if (iArray1[i][0])
		{
			ChangeClientTeam(iArray1[i][0], TEAM_BLUE);
			if (!IsFakeClient(iArray1[i][0]))
			{
				PrintCenterText(iArray1[i][0], "%t", "TeamChangedOne");
			}
		}
	}
	for (int i = 0; i < iSwaps; i++)
	{
		if (iArray2[i][0])
		{
			ChangeClientTeam(iArray2[i][0], TEAM_RED);
			if (!IsFakeClient(iArray2[i][0]))
			{
				PrintCenterText(iArray2[i][0], "%t", "TeamChangedOne");
			}
		}
	}
	g_bBlockDeath = false;
	PrintScrambleStats(iSwaps*2);
}

stock void DoRandomSort(int[] array, int count)
{
	if (!count)
		return;
	int iRedSelections, iBluSelections, iRedValidCount, iBluValidCount;
	int iBluCount = GetTeamClientCount(TEAM_BLUE);
	int iRedCount = GetTeamClientCount(TEAM_RED);
	int iTeamDiff, iLargerTeam, iAddToLarger;
	float fSelections = cvar_RandomSelections.FloatValue;
	int aReds[MAXPLAYERS+1][2];
	int aBlus[MAXPLAYERS+1][2];
	
	for (int i = 0; i < count; i++)
	{
		if (!array[i])
		{
			continue;
		}
		
		if (GetClientTeam(array[i]) == TEAM_RED)
		{
			aReds[iRedValidCount][0] = array[i];
			aReds[iRedValidCount][1] = 0;
			iRedValidCount++;
		}
		else
		{
			aBlus[iBluValidCount][0] = array[i];
			aBlus[iBluValidCount][1] = 0;
			iBluValidCount++;
		}
	}
	iRedSelections = RoundToCeil(fSelections * (float(iRedCount) + float(iBluCount)));
	iBluSelections = iRedSelections;
	iBluSelections /= 2;
	iRedSelections /= 2;

	if ((iTeamDiff = RoundFloat(FloatAbs(float(iRedCount) - float(iBluCount)))) >= 2)
	{
		iLargerTeam = GetLargerTeam();
		iAddToLarger = iTeamDiff / 2;
		iLargerTeam == TEAM_RED ? (iRedSelections += iAddToLarger):(iBluSelections+=iAddToLarger);
	}
	if (iRedSelections > iRedValidCount || iBluSelections > iBluValidCount)
	{
		if (iRedValidCount > iBluValidCount)
		{
			iRedSelections = iBluValidCount;
		}
		else if (iBluValidCount > iRedValidCount)
		{
			iBluSelections = iRedValidCount;
		}
		else
		{
			iRedSelections = iRedValidCount;
			iBluSelections = iBluValidCount;
		}
		
		int iTestRed, iTestBlu, iTestDiff;
		iTestBlu -= iBluSelections;
		iTestBlu += iRedSelections;
		iTestRed -= iRedSelections;
		iTestRed += iBluSelections;
		iTestDiff = RoundFloat(FloatAbs(float(iTestRed) - float(iTestBlu)));
		iTestDiff /= 2;
		
		if (iTestDiff >= 1)
		{
			if (iTestRed > iTestBlu)
			{
				iBluSelections -= iTestDiff;
			}
			else
			{
				iRedSelections -= iTestDiff;
			}
		}
	}
	
	SelectRandom(aReds, iRedValidCount, iRedSelections);
	SelectRandom(aBlus, iBluValidCount, iBluSelections);
	
	g_bBlockDeath = true;
	for (int i = 0; i < count; i++)
	{
		if (i < iBluValidCount)
		{
			if (aBlus[i][1] == 1 && aBlus[i][0])
			{
				ChangeClientTeam(aBlus[i][0], GetClientTeam(aBlus[i][0]) == TEAM_RED ? TEAM_BLUE:TEAM_RED);
				if (!IsFakeClient(aBlus[i][0]))
				{
					PrintCenterText(aBlus[i][0], "%t", "TeamChangedOne");
				}
			}
		}
		if (i < iRedValidCount)
		{
			if (aReds[i][1] == 1 && aReds[i][0])
			{
				ChangeClientTeam(aReds[i][0], GetClientTeam(aReds[i][0]) == TEAM_RED ? TEAM_BLUE:TEAM_RED);
				if (!IsFakeClient(aReds[i][0]))
				{
					PrintCenterText(aReds[i][0], "%t", "TeamChangedOne");
				}
			}
		}
	}
	g_bBlockDeath = false;
	PrintScrambleStats(iRedSelections+iBluSelections);
}

stock void SelectRandom(int[][] arr, int size, int numSelectsToMake) 
{ 
	int temp[MAXPLAYERS+1], deselected;
	while(--numSelectsToMake > 0) 
	{ 
		deselected = 0; 
		for(int i = 0; i < size; i++)
		{
			if (!arr[i][1]) 
			{
				temp[deselected++] = i;
			}
		}
		if (!deselected)
		{
			return;
		}
		int n = GetRandomInt(0, deselected - 1); 
		arr[temp[n]][1] = 1;
	}
} 

stock void ForceSpecToTeam()
{
	if (!g_bSelectSpectators)
	{
		return;
	}
	
	int iLarger = GetLargerTeam(), iSwapped = 1;
	
	if (iLarger)
	{
		int iDiff = GetAbsValue(GetTeamClientCount(TEAM_RED), GetTeamClientCount(TEAM_BLUE));	
		if (iDiff)
		{
			for (int i = 1; i< MaxClients; i++)
			{
				if (iDiff && IsClientInGame(i) && IsValidSpectator(i))
				{
					ChangeClientTeam(i, iLarger == TEAM_RED ? TEAM_BLUE : TEAM_RED);
					TF2_SetPlayerClass(i, TFClass_Scout);
					iSwapped = i;
					iDiff--;
				}
			}
		}
		bool boolyBool;
		for (int i = iSwapped; i < MaxClients; i++)
		{
			if (IsClientInGame(i) && IsValidSpectator(i))
			{
				ChangeClientTeam(i, boolyBool ? TEAM_RED:TEAM_BLUE);
				TF2_SetPlayerClass(i, TFClass_Scout);
				boolyBool = !boolyBool;
			}
		}		
	}
}

float GetClientScrambleScore(int client, e_ScrambleModes mode)
{
	int entity = GetPlayerResourceEntity(); 
	int Totalscore = GetEntProp(entity, Prop_Send, "m_iScore", _, client);
	
	switch (mode)
	{
		case score:
		{
			return float(Totalscore);
		}
		case kdRatio:		
		{
			return float(g_aPlayers[client][iFrags]) / float(g_aPlayers[client][iDeaths]);
		}
		case playerClass:
		{
			return float(view_as<int>(TF2_GetPlayerClass(client)));
		}
		default:
		{
			float fScore = float(Totalscore);
			fScore = fScore * fScore;
			if (!IsFakeClient(client))
			{
				float fClientTime = GetClientTime(client);
				float fTime = fClientTime / 60.0;
				fScore = fScore / fTime;
			}
			else
			{
				fScore = GetRandomFloat(0.0, 1.0);
			}
			return fScore;
		}
	}
}

stock void ScramblePlayers(e_ScrambleModes scrambleMode)
{
	if (scrambleMode == topSwap)
	{
		ForceSpecToTeam();
		PerformTopSwap();
		BlockAllTeamChange();
		return;
	}
	
	int iCount, iRedImmune, iBluImmune, iSwaps, iTempTeam, iImmuneTeam, iImmuneDiff, client;
	bool bToRed;
	int iValidPlayers[MAXPLAYERS+1];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (IsValidTeam(i) || IsValidSpectator(i)))
		{
			if (IsValidTarget(i))
			{
				iValidPlayers[iCount] = i;
				iCount++;
			}
			else
			{
				if (GetClientTeam(i) == TEAM_RED)
				{
					iRedImmune++;
				}
				
				if (GetClientTeam(i) == TEAM_BLUE)
				{
					iBluImmune++;
				}
			}
		}
	}
	if (g_iLastRoundWinningTeam)
	{
		bToRed = g_iLastRoundWinningTeam == TEAM_BLUE;
	}
	else
	{
		bToRed = GetRandomInt(0,1) == 0;
	}
	
	if ((iBluImmune || iRedImmune) && iRedImmune != iBluImmune)
	{
		if ((iImmuneDiff = (iRedImmune - iBluImmune)) > 0)
		{
			iImmuneTeam = TEAM_RED;
		}
		else
		{
			iImmuneDiff = RoundFloat(FloatAbs(float(iImmuneDiff)));
			iImmuneTeam = TEAM_BLUE;
		}
		bToRed = iImmuneTeam == TEAM_BLUE;
	}
	
	// 'any' array utilized here to allow floats in column 1 and ints in column 0 for SortCustom2D safely
	if (scrambleMode != random)
	{
		any scoreArray[MAXPLAYERS+1][2];
		for (int i = 0; i < iCount; i++)
		{
			scoreArray[i][0] = iValidPlayers[i];
			scoreArray[i][1] = GetClientScrambleScore(iValidPlayers[i], scrambleMode);
		}
		
		SortCustom2D(scoreArray, iCount, SortScoreAsc);
		
		for (int i = 0; i < iCount; i++)
		{
			iValidPlayers[i] = scoreArray[i][0];
		}	
	}
	
	if (scrambleMode == random)
	{
		ForceSpecToTeam();
		iCount = 0;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsValidTeam(i))
			{
				if (IsValidTarget(i))
				{
					iValidPlayers[iCount] = i;
					iCount++;
				}
			}
		}
		SortIntegers(iValidPlayers, iCount, Sort_Random);
		DoRandomSort(iValidPlayers, iCount);
		BlockAllTeamChange();
		return;
	}
	g_bBlockDeath = true;
	
	if (iImmuneTeam)
	{
		iImmuneTeam == TEAM_RED ? (bToRed = false):(bToRed = true);
	}
	for (int i = 0; i < iCount; i++)
	{
		client = iValidPlayers[i];
		iTempTeam = GetClientTeam(client);
		if (iImmuneDiff > 0)
		{
			ChangeClientTeam(client, iImmuneTeam == TEAM_RED ? TEAM_BLUE:TEAM_RED);
			iImmuneDiff--;
		}
		else
		{
			ChangeClientTeam(client, bToRed ? TEAM_RED:TEAM_BLUE);
			bToRed = !bToRed;
		}
		if (GetClientTeam(client) != iTempTeam)
		{
			iSwaps++;
			if (!IsFakeClient(client))
			{
				PrintCenterText(client, "%t", "TeamChangedOne");
			}
		}
		if (iTempTeam == 1)
		{
			TF2_SetPlayerClass(client, TFClass_Scout);
		}
	}
	
	g_bBlockDeath = false;
	LogMessage("Scramble changed %i client's teams", iSwaps);
	PrintScrambleStats(iSwaps);
	BlockAllTeamChange();
}

void PrintScrambleStats(int swaps)
{
	if (cvar_PrintScrambleStats.BoolValue)
	{
		float fScrPercent = float(swaps) / float(GetClientCount(true));
		char sPercent[6];
		fScrPercent = fScrPercent * 100.0;
		FloatToString(fScrPercent, sPercent, sizeof(sPercent));
		PrintToChatAll("\x01\x04[SM]\x01 %t", "StatsMessage", swaps, GetClientCount(true), sPercent);	
	}
}