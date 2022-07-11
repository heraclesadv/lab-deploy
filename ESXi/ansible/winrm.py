import winrm

winrmsession = winrm.Session('192.168.1.118', auth=('vagrant','vagrant'))