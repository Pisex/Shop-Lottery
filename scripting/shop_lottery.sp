#pragma semicolon 1
#include <shop>
#include <csgo_colors>
#undef REQUIRE_PLUGIN
#include <vip_core>
#pragma newdecls required

public Plugin myinfo =
{
	name		= "[Shop] Lottery",
	author		= "Pisex",
	version		= "1.1.0",
	url			= "Discord => Pisex#0023"
};

bool stavka[MAXPLAYERS+1],
	bMapEnd;
ArrayList g_hArrayList;

int MinCredits,
	MaxCredits,
	MinPlayerLottery,
	MinPlayer,
	Countdown,
	ResetTime,
	Percent,
	BankLottery,
	iLotteryCredits,
	TimeWait,
	UseVip;

char AdminFlags[64];


public void OnPluginStart()
{
	g_hArrayList = new ArrayList(ByteCountToCells(64));
	AddCommandListener(HookPlayerChat, "say"); // Перехватываем сообщение в чате
	AddCommandListener(HookPlayerChat, "say_team"); // Перехватываем сообщение в тим-чате
    RegConsoleCmd("sm_lottery",AdminSelect);
    if(Shop_IsStarted()) Shop_Started();

	LoadTranslations("shop_lottery.phrases");

	char cBuff[186];
	KeyValues KV = new KeyValues("Shop_Lottery");
	BuildPath(Path_SM, cBuff, sizeof(cBuff), "configs/shop/shop_lottery.ini");
	if (!KV.ImportFromFile(cBuff))
		SetFailState("Конфигурационный файл отсутствует!");

	MinCredits			= KV.GetNum("min_credits",1);
	MaxCredits			= KV.GetNum("max_credits",1000);
	MinPlayerLottery	= KV.GetNum("min_player_accept",2);
	MinPlayer			= KV.GetNum("min_player_start",2);
	Countdown			= KV.GetNum("countdown",67);
	Percent				= KV.GetNum("percent",2);
	TimeWait 			= KV.GetNum("waittime",30);
	UseVip 				= KV.GetNum("vip",1);
	KV.GetString("lottery_flags",AdminFlags,sizeof AdminFlags);

	if(UseVip)
		if(VIP_IsVIPLoaded())
			VIP_OnVIPLoaded();
}

public void VIP_OnVIPLoaded()
{
	VIP_RegisterFeature("VIP_LotteryAccess",BOOL,SELECTABLE,VIP_Select);
}

public bool VIP_Select(int iClient, const char[] szFeature)
{
	FakeClientCommand(iClient,"sm_lottery");
}

public void Shop_Started()
{	
	Shop_AddToAdminMenu(OnAdminDisplay, OnAdminSelect);
}

public void OnMapEnd()
{
	bMapEnd=true;
}

public void OnMapStart()
{
	bMapEnd=false;
	ResetTime = 0;
}

public void OnPluginEnd()
{
	Shop_RemoveFromAdminMenu(OnAdminDisplay, OnAdminSelect);
	
	if(UseVip)
		VIP_UnregisterFeature("VIP_LotteryAccess");
}

public int OnAdminDisplay(int client, char[] buffer, int maxlength)
{
	Format(buffer, maxlength, "Лотерея");
}

public bool OnAdminSelect(int iClient)
{
	AdminSelect(iClient, 0);
    return true;
}

public Action AdminSelect(int iClient,int args)
{
	if(GetUserFlagBits(iClient) & (ReadFlagString(AdminFlags) | ReadFlagString("z")))
	{
		Menu hMenu = new Menu(LotteryAdminMenu);
		hMenu.SetTitle("Лотерея");
		char cd[32];
		bool cd_time;
		if(ResetTime > 0){FormatEx(cd,sizeof cd,"%t","PlayButton_Countdown", ResetTime/ 60, ResetTime % 60);cd_time = true;}
		else {FormatEx(cd,sizeof cd,"%t","PlayButton");cd_time = false;}
		hMenu.AddItem("go",cd,cd_time?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
		if(GetUserFlagBits(iClient) & ReadFlagString("z"))
		{
			FormatEx(cd,sizeof cd,"%T","ResetButton",iClient);
			hMenu.AddItem("reset", cd);
			hMenu.ExitBackButton = true;
		}
		hMenu.Display(iClient, 0);
		return Plugin_Handled;
	}
	if(UseVip)
	{
		if(VIP_GetClientFeatureStatus(iClient, "VIP_LotteryAccess") != NO_ACCESS)
		{
			Menu hMenu = new Menu(LotteryAdminMenu);
			hMenu.SetTitle("Лотерея");
			char cd[32];
			bool cd_time;
			if(ResetTime > 0){FormatEx(cd,sizeof cd,"%t","PlayButton_Countdown", ResetTime/ 60, ResetTime % 60);cd_time = true;}
			else {FormatEx(cd,sizeof cd,"%t","PlayButton");cd_time = false;}
			hMenu.AddItem("go",cd,cd_time?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
			if(GetUserFlagBits(iClient) & ReadFlagString("z"))
			{
				FormatEx(cd,sizeof cd,"%T","ResetButton",iClient);
				hMenu.AddItem("reset", cd);
				hMenu.ExitBackButton = true;
			}
			hMenu.Display(iClient, 0);
			return Plugin_Handled;
		}
	}
    return Plugin_Handled;
}

public int LotteryAdminMenu(Menu menu, MenuAction action_cash, int iClient, int iItem)
{
	switch(action_cash)
	{
		case MenuAction_Select:
		{
			char item[32],
				cBuff[186];
			int players;
			menu.GetItem(iItem, item, sizeof item);
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) > 1)
				{
					players+=1;
				}
			}
			if(StrEqual(item, "go") && players >= MinPlayer)
            {
                stavka[iClient] = true;
				FormatEx(cBuff,sizeof cBuff,"%T","LotteryPrice",iClient,MinCredits,MaxCredits);
                CGOPrintToChat(iClient, cBuff);
            }
			else if(StrEqual(item, "reset"))
			{
				ResetTime = 0;
				FormatEx(cBuff,sizeof cBuff,"%T","ResetCoolDown",iClient);
                CGOPrintToChat(iClient, cBuff);
				AdminSelect(iClient,0);
			}
			else
			{
				FormatEx(cBuff,sizeof cBuff,"%T","FewPlayers",iClient);
				CGOPrintToChat(iClient,cBuff);
			}
		}
		case MenuAction_Cancel:
		{
			if (iItem == MenuCancel_ExitBack)
			{
				Shop_ShowAdminMenu(iClient);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public Action HookPlayerChat(int iClient, char[] command, int args)
{
	char LotteryCredits[8];
	GetCmdArg (1, LotteryCredits, sizeof LotteryCredits);
	if(stavka[iClient] == true && (MinCredits <= StringToInt(LotteryCredits) <=MaxCredits))
	{
		stavka[iClient] = false;
		BankLottery = 0;
		iLotteryCredits = StringToInt(LotteryCredits);
		ClearArray(g_hArrayList);
		StartLottery(iClient);
		ResetTime = Countdown+TimeWait;
		CreateTimer(1.0,TimerCountDown,ResetTime);
		return Plugin_Handled;
  	}
	else if(stavka[iClient] == true)
	{
		char cBuff[186];
		FormatEx(cBuff,sizeof cBuff,"%T","LotteryPriceNoCorrect",iClient);
        CGOPrintToChat(iClient, cBuff);
	}
  	return Plugin_Continue;
}

void StartLottery(int iClient)
{
    char szBuffer[256];
	Panel hPanel = new Panel();
	FormatEx(szBuffer, sizeof szBuffer, "%t","Lottery_MenuSelect",iLotteryCredits);
	hPanel.SetTitle(szBuffer);
	hPanel.DrawItem("Участвовать");
	hPanel.DrawItem("Не участвовать");
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && !IsFakeClient(i) && !IsClientSourceTV(i))
			if(i != iClient)
				hPanel.Send(i, PanelCallback, TimeWait);

	delete hPanel;

	CreateTimer(1.0, Timer_CallBack, TimeWait);
}

public int PanelCallback(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	char cBuff[186];
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(iItem)
			{
				case 1:
				{
					if(Shop_GetClientCredits(iClient) > iLotteryCredits)
                    {
                        g_hArrayList.Push(iClient);
						FormatEx(cBuff,sizeof cBuff,"%t","LotteryAccept",iClient,g_hArrayList.Length);
                        CGOPrintToChatAll(cBuff);
                        Shop_TakeClientCredits(iClient,iLotteryCredits);
                        BankLottery += iLotteryCredits;
                    }
				}
				case 2:
				{
					FormatEx(cBuff,sizeof cBuff,"%T","LotteryDeny",iClient);
					CGOPrintToChat(iClient, cBuff);
				}
			}
		}
	}
	return 0;
}

public Action Timer_CallBack(Handle timer, int time)
{
	char cBuff[186];
	int iLenght = g_hArrayList.Length;
	if(bMapEnd == false)
	{
		if(time-- == 0)
		{
			if(iLenght >= MinPlayerLottery)
			{
				GoLottery();
			}
			else
			{
				for(int i = 0; i <= (iLenght-1); i++)
				{
					int iClient = g_hArrayList.Get(i);
					FormatEx(cBuff,sizeof cBuff,"%T","LotteryPlayersFew",iClient);
					ResetTime = 0;
					CGOPrintToChat(iClient,cBuff);
					Shop_GiveClientCredits(iClient,iLotteryCredits);
				}
			}
			return Plugin_Stop;
		}
		FormatEx(cBuff,sizeof cBuff,"%t","TimerLottery",time);
		PrintHintTextToAll(cBuff);
		CreateTimer(1.0, Timer_CallBack, time);
	}
	else
	{
		for(int i = 0; i <= (iLenght-1); i++)
		{
			int iClient = g_hArrayList.Get(i);
			FormatEx(cBuff,sizeof cBuff,"%T","LotteryMapEnd",iClient);
			CGOPrintToChat(iClient,cBuff);
			Shop_GiveClientCredits(iClient,iLotteryCredits);
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void GoLottery()
{
	char cBuff[186];
    int iClient = g_hArrayList.Get(GetRandomInt(0, g_hArrayList.Length - 1));
	if(Percent) BankLottery -=BankLottery*Percent/100;
	if(iClient && IsClientInGame(iClient) && !IsFakeClient(iClient))
	{
		Shop_GiveClientCredits(iClient, BankLottery);
		FormatEx(cBuff,sizeof cBuff,"%t","WinLottery",iClient,BankLottery);
	}
	else
	{
		FormatEx(cBuff,sizeof cBuff,"%t","WinLotteryPlayerLeave");
	}
	CGOPrintToChatAll(cBuff);
}

public Action TimerCountDown(Handle timer, int time)
{
	if(time-- == 0)
	{
		ResetTime = 0;
	}
	else
	{
		ResetTime--;
		CreateTimer(1.0, TimerCountDown, time);
	}
	return Plugin_Continue;
}