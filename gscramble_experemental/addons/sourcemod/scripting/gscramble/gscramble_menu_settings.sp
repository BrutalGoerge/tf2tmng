/************************************************************************
*************************************************************************
gScramble menu settings (Modernized)
Description:
	Menu coding for the gscramble addon
*************************************************************************
*************************************************************************/

TopMenuObject g_Category = INVALID_TOPMENUOBJECT;

public void OnAdminMenuReady(Handle aTopMenu)
{
	if (!cvar_MenuIntegrate.BoolValue)
	{
		return;
	}
	
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
	
	if (topmenu == g_hAdminMenu)
	{
		return;
	}
	
	g_Category = INVALID_TOPMENUOBJECT;
	g_hAdminMenu = topmenu;
	TopMenuObject menu_category = g_hAdminMenu.FindCategory(ADMINMENU_SERVERCOMMANDS);
	
	if (menu_category != INVALID_TOPMENUOBJECT)
	{
		// Modern TopMenu AddItem dropped the 'TopMenuObject_Item' parameter
		g_Category = g_hAdminMenu.AddItem("gScramble", Handle_Category, menu_category);
	}
}

public void Handle_Category(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption:
		{
			Format(buffer, maxlength, "gScramble Commands");
		}
		
		case TopMenuAction_SelectOption:
		{
			Format(buffer, maxlength, "Select a Function");
			char sBuffer[33];
			
			// Modern menus are object-oriented Methodmaps
			Menu hScrambleOptionsMenu = new Menu(Handle_ScrambleFunctionMenu);
			hScrambleOptionsMenu.SetTitle("Choose A Function");
			hScrambleOptionsMenu.ExitButton = true;
			hScrambleOptionsMenu.ExitBackButton = true;
			
			if (CheckCommandAccess(param, "sm_scrambleround", ADMFLAG_BAN))
			{
				hScrambleOptionsMenu.AddItem("0", "Start a Scramble");
			}
			
			if (CheckCommandAccess(param, "sm_scramblevote", ADMFLAG_BAN))
			{
				hScrambleOptionsMenu.AddItem("1", "Start a Vote");
				Format(sBuffer, sizeof(sBuffer), "Reset %i Vote(s)", g_iVotes);
				hScrambleOptionsMenu.AddItem("2", sBuffer);
			}
			
			if (CheckCommandAccess(param, "sm_forcebalance", ADMFLAG_BAN))
			{
				hScrambleOptionsMenu.AddItem("3", "Force Team Balance");
			}
			
			if (CheckCommandAccess(param, "sm_cancel", ADMFLAG_BAN))
			{
				if (g_bScrambleNextRound || g_hScrambleDelay != null)
				{
					Format(sBuffer, sizeof(sBuffer), "Cancel (Pending Scramble)");
					hScrambleOptionsMenu.AddItem("4", sBuffer);
				}					
				else if (g_bAutoScramble && g_RoundState == bonusRound)
				{
					Format(sBuffer, sizeof(sBuffer), "Cancel (Auto-Scramble Check)");
					hScrambleOptionsMenu.AddItem("4", sBuffer);
				}
			}
			
			hScrambleOptionsMenu.Display(param, MENU_TIME_FOREVER);
		}
	}
}

void ShowScrambleVoteMenu(int client)
{
	Menu scrambleVoteMenu = new Menu(Handle_ScrambleVote);
	
	scrambleVoteMenu.SetTitle("Choose a Method");
	scrambleVoteMenu.ExitButton = true;
	scrambleVoteMenu.ExitBackButton = true;
	scrambleVoteMenu.AddItem("round", "Vote for End-of-Round Scramble");
	scrambleVoteMenu.AddItem("now", "Vote for Scramble Now");
	scrambleVoteMenu.Display(client, MENU_TIME_FOREVER);
}

void ShowScrambleSelectionMenu(int client)
{
	Menu scrambleMenu = new Menu(Handle_Scramble);
	
	scrambleMenu.SetTitle("Choose a Method");
	scrambleMenu.ExitButton = true;
	scrambleMenu.ExitBackButton = true;
	scrambleMenu.AddItem("round", "Scramble Next Round");
	if (CheckCommandAccess(client, "sm_scramble", ADMFLAG_BAN))
	{
		scrambleMenu.AddItem("now", "Scramble Teams Now");
	}
	
	scrambleMenu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_ScrambleFunctionMenu(Menu functionMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sOption[2];
			functionMenu.GetItem(param2, sOption, sizeof(sOption));
			
			switch (StringToInt(sOption))
			{
				case 0: ShowScrambleSelectionMenu(client);
				case 1: ShowScrambleVoteMenu(client);
				case 2: PerformVoteReset(client);
				case 3: PerformBalance(client);
				case 4: PerformCancel(client);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				g_hAdminMenu.Display(client, TopMenuPosition_LastCategory);
			}
		}		
		case MenuAction_End:
			delete functionMenu;
	}
	return 0;
}

public int Handle_ScrambleVote(Menu scrambleVoteMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char method[6]; 
			ScrambleTime iMethod;
			scrambleVoteMenu.GetItem(param2, method, sizeof(method));
			if (StrEqual(method, "round", true))
			{
				iMethod = Scramble_Round;			
			}
			else
			{
				iMethod = Scramble_Now;
			}
			
			PerformVote(client, iMethod);
		}
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				g_hAdminMenu.Display(client, TopMenuPosition_LastCategory);
			}
		}
		
		case MenuAction_End:
		{
			delete scrambleVoteMenu;
		}
	}
	return 0;
}

public int Handle_Scramble(Menu scrambleMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!param2)
			{
				SetupRoundScramble(client);
			}
			else
			{
				Menu scrambleNowMenu = new Menu(Handle_ScrambleNow);
				
				scrambleNowMenu.SetTitle("Choose a Method");
				scrambleNowMenu.ExitButton = true;
				scrambleNowMenu.ExitBackButton = true;
				scrambleNowMenu.AddItem("5", "Delay 5 seconds");
				scrambleNowMenu.AddItem("15", "Delay 15 seconds");
				scrambleNowMenu.AddItem("30", "Delay 30 seconds");
				scrambleNowMenu.AddItem("60", "Delay 60 seconds");
				scrambleNowMenu.Display(client, MENU_TIME_FOREVER);
			}
		}
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				g_hAdminMenu.Display(client, TopMenuPosition_LastCategory);
			}
		}
		
		case MenuAction_End:
		{
			delete scrambleMenu;	
		}
	}
	return 0;
}

public int Handle_ScrambleNow(Menu scrambleNowMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			Menu respawnSelectMenu = new Menu(Handle_RespawnMenu);
		
			if (g_hScrambleNowPack != null)
			{
				delete g_hScrambleNowPack;
			}
			
			g_hScrambleNowPack = new DataPack();
		
			respawnSelectMenu.SetTitle("Respawn Players After Scramble?");
			respawnSelectMenu.ExitButton = true;
			respawnSelectMenu.ExitBackButton = true;
			respawnSelectMenu.AddItem("Yep", "Yes");
			respawnSelectMenu.AddItem("Noep", "No");
			respawnSelectMenu.Display(client, MENU_TIME_FOREVER);
			char delay[3];
			scrambleNowMenu.GetItem(param2, delay, sizeof(delay));		
			g_hScrambleNowPack.WriteFloat(StringToFloat(delay));
		}
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				g_hAdminMenu.Display(client, TopMenuPosition_LastCategory);
			}
		}
	
		case MenuAction_End:
		{
			delete scrambleNowMenu;
		}
	}
	return 0;
}

public int Handle_RespawnMenu(Menu scrambleResetMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			int respawn = !param2 ? 1 : 0 ;
			g_hScrambleNowPack.WriteCell(respawn);
			Menu modeSelectMenu = new Menu(Handle_ModeMenu);
			
			modeSelectMenu.SetTitle("Select a scramble sort mode");
			modeSelectMenu.ExitButton = true;
			modeSelectMenu.ExitBackButton = true;
			
			modeSelectMenu.AddItem("1", "Random");
			modeSelectMenu.AddItem("2", "Player-Score");
			modeSelectMenu.AddItem("3", "Player-Score^2/Connect time (in minutes)");
			modeSelectMenu.AddItem("4", "Player kill-Death ratios");
			modeSelectMenu.AddItem("5", "Swap the top players on each team");
			// APIs removed from menu items here
			modeSelectMenu.AddItem("13", "Sort By Player Classes");
			modeSelectMenu.AddItem("14", "Random Sort-Mode");
			modeSelectMenu.Display(client, MENU_TIME_FOREVER);
		}
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				g_hAdminMenu.Display(client, TopMenuPosition_LastCategory);
			}
		}
		
		case MenuAction_End:
		{
			delete scrambleResetMenu;
		}
			
	}
	return 0;
}

public int Handle_ModeMenu(Menu modeMenu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			g_hScrambleNowPack.Reset();
			float delay = g_hScrambleNowPack.ReadFloat();
			bool respawn = g_hScrambleNowPack.ReadCell() ? true : false;
				
			e_ScrambleModes mode = view_as<e_ScrambleModes>(param2+1);
			delete g_hScrambleNowPack;
			g_hScrambleNowPack = null;
			PerformScrambleNow(client, delay, respawn, mode);		
		}
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				g_hAdminMenu.Display(client, TopMenuPosition_LastCategory);
			}
		}
		
		case MenuAction_End:
		{
			delete modeMenu;
		}
	}
	return 0;
}

void RestoreMenuCheck(int rejoinClient, int team)
{
	int client, iTemp;
	for (int i = 1; i<= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == team)
		{
			if (g_aPlayers[i][iBalanceTime] > GetTime() && g_aPlayers[i][iBalanceTime] > iTemp)
			{
				client = i;
				iTemp = g_aPlayers[i][iBalanceTime];
			}
		}
	}
	
	if (!client)
	{
		return;
	}
	
	char name[MAX_NAME_LENGTH+1];
	GetClientName(rejoinClient, name, sizeof(name));
	
	PrintToChat(client, "\x01\x04[SM]\x01 %t", "RestoreInnocentTeam", name);
	
	Menu RestoreMenu = new Menu(Handle_RestoreMenu);
	
	RestoreMenu.SetTitle("Retore your old team?");
	RestoreMenu.AddItem("yes", "Yes");
	RestoreMenu.AddItem("no", "No");
	RestoreMenu.Display(client, 20);
}

void AddBuddy(int client, int buddy)
{
	if (!client || !buddy || !IsClientInGame(client) || !IsClientInGame(buddy) || client == buddy)
	{
		return;
	}
	
	if (g_aPlayers[buddy][iBuddy])
	{
		PrintToChat(client, "\x01\x04[SM]\x01 %t", "AlreadyHasABuddy");
		return;
	}
	
	char clientName[MAX_NAME_LENGTH];
	char buddyName[MAX_NAME_LENGTH];
	GetClientName(client, clientName, sizeof(clientName));
	GetClientName(buddy, buddyName, sizeof(buddyName));
	
	if (g_aPlayers[client][iBuddy])
	{
		PrintToChat(g_aPlayers[client][iBuddy], "\x01\x04[SM]\x01 %t", "ChoseANewBuddy", clientName);
	}
	
	g_aPlayers[client][iBuddy] = buddy;
	PrintToChat(buddy, "\x01\x04[SM]\x01 %t", "SomeoneAddedYou", clientName);
	PrintToChat(client, "\x01\x04[SM]\x01 %t", "AddedBuddy", buddyName);
}

void ShowBuddyMenu(int client)
{
	Menu menu = new Menu(BuddyMenuCallback);
	menu.SetTitle("Select a Buddy");
	AddTargetsToMenu(menu,0);
	menu.Display(client, MENU_TIME_FOREVER);
}

public int BuddyMenuCallback(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char selection[10];
			menu.GetItem(param2, selection, sizeof(selection));
			AddBuddy(client, GetClientOfUserId(StringToInt(selection)));			
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

public int Handle_RestoreMenu(Menu RestoreMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!param2)
			{
				char name[MAX_NAME_LENGTH+1];
				GetClientName(client, name, sizeof(name));
				PrintToChatAll("\x01\x04[SM]\x01 %t", "RejoinMessage", name);
				g_bBlockDeath = true;
				CreateTimer(0.1, Timer_BalanceSpawn, GetClientUserId(client));
				ChangeClientTeam(client, GetClientTeam(client) == TEAM_RED ? TEAM_BLUE : TEAM_RED);
				g_bBlockDeath = false;
				g_aPlayers[client][iBalanceTime] = GetTime();
			}
		}
	
		case MenuAction_End:
		{
			delete RestoreMenu;
		}
	}
	return 0;
}