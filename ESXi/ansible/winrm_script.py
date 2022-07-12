import winrm
from var import *

print("Win 10 : Using WinRM to download and run Cybereason installer.")
winrmsession = winrm.Session(WIN_IP, auth=('vagrant','vagrant'))
ps_script = """
$client = new-object System.Net.WebClient
$client.DownloadFile("http://192.168.1.52/CybereasonWindows.exe","C:\\tmp\\CybereasonWindows.exe")"""
r = winrmsession.run_ps(ps_script)
print("Status code: " + str(r.status_code))
print("std_out: " + str(r.std_out))
print("std_err: " + str(r.std_err))

ps_script = """
C:\\tmp\\CybereasonWindows.exe /install /quiet /norestart 
"""
r = winrmsession.run_ps(ps_script)
print("Status code: " + str(r.status_code))
print("std_out: " + str(r.std_out))
print("std_err: " + str(r.std_err))

print("Win 10 B : Using WinRM to download and run Cybereason installer.")
winrmsession = winrm.Session(WINB_IP, auth=('vagrant','vagrant'))
ps_script = """
$client = new-object System.Net.WebClient
$client.DownloadFile("http://192.168.1.52/CybereasonWindows.exe","C:\\tmp\\CybereasonWindows.exe")"""
r = winrmsession.run_ps(ps_script)
print("Status code: " + str(r.status_code))
print("std_out: " + str(r.std_out))
print("std_err: " + str(r.std_err))

ps_script = """
C:\\tmp\\CybereasonWindows.exe /install /quiet /norestart 
"""
r = winrmsession.run_ps(ps_script)
print("Status code: " + str(r.status_code))
print("std_out: " + str(r.std_out))
print("std_err: " + str(r.std_err))

print("DC : Using WinRM to download and run Cybereason installer.")
winrmsession = winrm.Session(DC_IP, auth=('vagrant','vagrant'))
ps_script = """
$client = new-object System.Net.WebClient
$client.DownloadFile("http://192.168.1.52/CybereasonWindows.exe","C:\\Users\\vagrant\\CybereasonWindows.exe")"""
r = winrmsession.run_ps(ps_script)
print("Status code: " + str(r.status_code))
print("std_out: " + str(r.std_out))
print("std_err: " + str(r.std_err))

ps_script = """
C:\\Users\\vagrant\\CybereasonWindows.exe /install /quiet /norestart 
"""
r = winrmsession.run_ps(ps_script)
print("Status code: " + str(r.status_code))
print("std_out: " + str(r.std_out))
print("std_err: " + str(r.std_err))