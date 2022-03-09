: delete the current env variables
REG delete HKCU\Environment /F /V APPLIANCESTORE
REG delete HKCU\Environment /F /V CURRENT_LESSON

: set both env-variables
setx APPLIANCESTORE C:\Users\mh0071\.govm_appliance
setx CURRENT_LESSON excel

: WSLENV is a special variable that is making the sharing of env variables between win and linux easy
setx WSLENV %WSLENV%:CURRENT_LESSON/u:APPLIANCESTORE/p