#include "fle_win32_framework.h"
#include "config.h"
#include <iostream>
#include <cstdlib>

// Declare global stuff that you need to use inside the functions.
fle_TrayWindow * window;

fle_TrayMenuItem * mnuStartServer;
fle_TrayMenuItem * mnuStopServer;
fle_TrayMenuItem * mnuLoadBrowser;
fle_TrayMenuItem * mnuOptions;
fle_TrayMenuItem * mnuRunUserLogsIn;
fle_TrayMenuItem * mnuRunAtStartup;
fle_TrayMenuItem * mnuAutoStart;
fle_TrayMenuItem * mnuExit;
fle_TrayMenuItem * showKaliteLogs;


bool needNotify = false;
bool isServerStarting = false;

void kaliteScriptPath(char *buffer, const DWORD MAX_SIZE)
{
	/*
		Gets the path to kalite.bat script directory, from KALITE_SCRIPT_DIR environment variable.
		KALITE_SCRIPT_DIR should be set at install time to e.g. C:\Python27\Scripts, or wherever pip puts the kalite.bat script.
		
		:param char *buffer: the buffer to hold the path string. If KALITE_SCRIPT_DIR is not set or is longer than MAX_SIZE, then this will be set to 0.
		:param const DWORD MAX_SIZE: the max size of the buffer parameter. Must be large enough for path string and terminating null byte.
		:returns: void
	*/
	LPCSTR kalite_script_dir = "KALITE_SCRIPT_DIR";
	DWORD bufsize = GetEnvironmentVariableA(kalite_script_dir, buffer, MAX_SIZE);
	if (bufsize == 0)
	{
		window->sendTrayMessage("KA Lite", "Error: Environment variable KALITE_SCRIPT_DIR is not set.");
		buffer = 0;
	} 
	else if (bufsize > MAX_SIZE)
	{
		char err_message[255];
		sprintf(err_message, "Error: the value of KALITE_SCRIPT_DIR must be less than %d, but it was length %d. Please start KA Lite from the command line.", MAX_SIZE, bufsize);
		window->sendTrayMessage("KA Lite", err_message);
		buffer = 0;
	}
	return;
}

void kaliteHomePath(char *buffer, const DWORD MAX_SIZE)
{
	/*
	Get the path of kalite.pid file directory, from KALITE_HOME environment variable.
	*/
	LPCSTR kalite_script_dir = "KALITE_HOME";
	DWORD bufsize = GetEnvironmentVariableA(kalite_script_dir, buffer, MAX_SIZE);
	if (bufsize == 0)
	{
		const char* homeDrive = getenv("HOMEDRIVE");
		const char* homePath = getenv("HOMEPATH");
		char * userHomePath = new char[strlen(homeDrive) + strlen(homePath) + 1];
		strcpy(userHomePath, homeDrive);
		strcat(userHomePath, homePath);
		char * kalitedefaultPAth = new char[strlen(userHomePath) + strlen("\\.kalite") + 1];
		strcpy(kalitedefaultPAth, userHomePath);
		strcat(kalitedefaultPAth, "\\.kalite");
		struct stat fileAtt;
		if (stat(kalitedefaultPAth, &fileAtt) != 0) {
			buffer = 0;
			return;
		}
		else {
			strcpy(buffer, kalitedefaultPAth);
		}
	}
	else if (bufsize > MAX_SIZE)
	{
		char err_message[255];
		sprintf(err_message, "Error: the value of KALITE_HOME must be less than %d, but it was length %d. Please start KA Lite from the command line.", MAX_SIZE, bufsize);
		window->sendTrayMessage("KA Lite", err_message);
		buffer = 0;
	}
	return;
}

void startServerAction()
{
	const DWORD MAX_SIZE = 255;
	char script_dir[MAX_SIZE];
	kaliteScriptPath(script_dir, MAX_SIZE);
	if(!runShellScript("kalite.bat", "start", script_dir))
	{
		// Handle error.
	}
	else
	{
		mnuStartServer->disable();

		needNotify = true;
		isServerStarting = true;

		window->sendTrayMessage("KA Lite", "The server is starting... please wait");
	}
}

void stopServerAction()
{
	const DWORD MAX_SIZE = 255;
	char script_dir[MAX_SIZE];
	kaliteScriptPath(script_dir, MAX_SIZE);
	if(!runShellScript("kalite.bat", "stop", script_dir))
	{
		// Handle error.
	}
	else
	{
		mnuStartServer->enable();
		mnuStopServer->disable();
		mnuLoadBrowser->disable();
	}
}

void loadBrowserAction()
{
	if(!loadBrowser("http://127.0.0.1:8008/"))
	{
		// Handle error.
	}
}

void exitKALiteAction()
{
	if(ask("Exiting..." , "Really want to exit KA Lite?"))
	{
		stopServerAction();
		window->quit();
	}
}

void runUserLogsInAction()
{
	if(mnuRunUserLogsIn->isChecked())
	{
		if(!runShellScript("guitools.vbs", "1", NULL))
		{
			// Handle error.
			printConsole("Failed to remove startup schortcut.\n");
		}
		else
		{
			mnuRunUserLogsIn->uncheck();
			setConfigurationValue("RUN_AT_LOGIN", "FALSE");
		}
	}
	else
	{
		if(!runShellScript("guitools.vbs", "0", NULL))
		{
			// Handle error.
			printConsole("Failed to add startup schortcut.\n");
		}
		else
		{
			mnuRunUserLogsIn->check();
			setConfigurationValue("RUN_AT_LOGIN", "TRUE");
		}
	}
}

void runAtStartupAction()
{
	if(mnuRunAtStartup->isChecked())
	{
		if(!runShellScript("guitools.vbs", "5", NULL))
		{
			// Handle error.
			printConsole("Failed to remove task to run at startup.\n");
		}
		else
		{
			mnuRunAtStartup->uncheck();
			setConfigurationValue("RUN_AT_STARTUP", "FALSE");
		}
	}
	else
	{
		if(!runShellScript("guitools.vbs", "4", NULL))
		{
			// Handle error.
			printConsole("Failed to add task to run at startup.\n");
		}
		else
		{
			mnuRunAtStartup->check();
			setConfigurationValue("RUN_AT_STARTUP", "TRUE");
		}
	}
}

void autoStartServerAction()
{
	if(mnuAutoStart->isChecked())
	{
		mnuAutoStart->uncheck();
		setConfigurationValue("AUTO_START", "FALSE");
	}
	else
	{
		mnuAutoStart->check();
		setConfigurationValue("AUTO_START", "TRUE");
	}
}

void showKaliteServerLogs()
{	
	const DWORD MAX_SIZE = 255;
	std:string filePath = "\\server.log";
	char homePath[MAX_SIZE];
	kaliteHomePath(homePath, MAX_SIZE);
	std::string str(homePath);
	struct stat fileAtt;
	std::string kaliteLogsPath = homePath + filePath;
	if (stat(&kaliteLogsPath[0u], &fileAtt) != 0) {
		window->sendTrayMessage("KA Lite", "The KA Lite log file doesn't exist.");
	}
	else {
		string startCmd = "start notepad.exe ";
		string runCmd = startCmd + kaliteLogsPath;
		system(&runCmd[0u]);
	}
}

void checkServerThread()
{
	// We can handle things like checking if the server is online and controlling the state of each component.
	if(isServerOnline("KA Lite session", "http://127.0.0.1:8008/"))
	{
		// Validate if running port 8008 is used at KA Lite server.
		const DWORD MAX_SIZE = 255;
		std:string filePath = "\\kalite.pid";
		char home_path[MAX_SIZE];
		kaliteHomePath(home_path, MAX_SIZE);
		std::string str(home_path);
		std::string kalite_pid_path = home_path + filePath;
		char *pid_path = &kalite_pid_path[0u];
		struct stat fileAtt;
		if (stat(pid_path, &fileAtt) != 0) {
			if (needNotify)
			{
				mnuStartServer->enable();
				window->sendTrayMessage("KA Lite", "Port :8008 is occupied. Please close the process that's using it to start the KA Lite");
				needNotify = false;
			}
		}
		else {
			mnuStartServer->disable();
			mnuStopServer->enable();
			mnuLoadBrowser->enable();
			if (needNotify)
			{
				window->sendTrayMessage("KA Lite is running", "The server will be accessible locally at: http://127.0.0.1:8008/ or you can select \"Load in browser.\"");
				needNotify = false;
			}

			isServerStarting = false;
		}
		
	}
	else
	{
		if(!isServerStarting)
		{
			mnuStartServer->enable();
			mnuStopServer->disable();
			mnuLoadBrowser->disable();
		}
	}
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
	// REF: http://stackoverflow.com/questions/8799646/preventing-multiple-instances-of-my-application
	// Prevent the KA Lite application to execute multiple instances.
	HANDLE hMutex = CreateMutexA(NULL, FALSE, "KA Lite");
	DWORD dwMutexWaitResult = WaitForSingleObject(hMutex, 0);
	if (dwMutexWaitResult != WAIT_OBJECT_0)
	{
		MessageBox(HWND_DESKTOP, TEXT("KA Lite application is already running. \nRight click the KA Lite icon in the task-tray to start the server."), TEXT("KA Lite information"), MB_OK | MB_ICONINFORMATION);
		CloseHandle(hMutex);
		return false;
	}

	startThread(NULL, TRUE, 3000, &checkServerThread);

	window = new fle_TrayWindow(&hInstance);
	window->setTrayIcon("images\\logo48.ico");

	mnuStartServer = new fle_TrayMenuItem("Start Server.", &startServerAction);
	mnuStopServer = new fle_TrayMenuItem("Stop Server.", &stopServerAction);
	mnuLoadBrowser = new fle_TrayMenuItem("Load in browser.", &loadBrowserAction);
	mnuOptions = new fle_TrayMenuItem("Options", NULL);
	mnuRunUserLogsIn = new fle_TrayMenuItem("Run KA Lite when the user logs in.", &runUserLogsInAction);
	mnuRunAtStartup = new fle_TrayMenuItem("Run KA Lite at system startup.", &runAtStartupAction);
	mnuAutoStart = new fle_TrayMenuItem("Auto-start server when KA Lite is run.", &autoStartServerAction);
	mnuExit = new fle_TrayMenuItem("Exit KA Lite.", &exitKALiteAction);
	showKaliteLogs = new fle_TrayMenuItem("Show KA Lite logs.", &showKaliteServerLogs);

	mnuOptions->setSubMenu();
	mnuOptions->addSubMenu(mnuRunUserLogsIn);
	mnuOptions->addSubMenu(mnuRunAtStartup);
	mnuOptions->addSubMenu(mnuAutoStart);
	
	window->addMenu(mnuStartServer);
	window->addMenu(mnuStopServer);
	window->addMenu(mnuLoadBrowser);
	window->addMenu(showKaliteLogs);
	window->addMenu(mnuOptions);
	window->addMenu(mnuExit);

	mnuStopServer->disable();
	mnuLoadBrowser->disable();

	// Load configurations.
	if(isSetConfigurationValueTrue("RUN_AT_LOGIN"))
	{
		mnuRunUserLogsIn->check();
	}
	if(isSetConfigurationValueTrue("RUN_AT_STARTUP"))
	{
		mnuRunAtStartup->check();
	}
	if(isSetConfigurationValueTrue("AUTO_START"))
	{
		mnuAutoStart->check();
		startServerAction();
	}

	window->show();

	return 0;
}

