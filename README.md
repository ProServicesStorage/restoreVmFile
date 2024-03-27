# restoreVmFile
This script loops through feeder txt file with one VMWare VM per line and restores a specified file in place for all VM's

- If using domain credentials then use format `user@domain.example`
- Create folder `C:\cvscripts` and run script from this folder

Change the @body fileoption and destination sections to specify the file to be restored
Change the @body guestUserPassword. Convert your password to base64. You can use this [site](https://base64.guru/converter)
Recommend generating the JSON via the Command Center Equivalent API option then using below as a reference for variable replacement
Yes I know!! The script has too many manual steps and could be improved.
